from __future__ import annotations

import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

import duckdb


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

S3_DATA_PATH = (
    "s3://ducklake-definitive-guide/"
    "chapter9/python-concurrency/"
)

# Example:
# export DUCKLAKE_PG_DSN="dbname=matthewmartin user=matthewmartin password=postgres host=127.0.0.1"
PG_DSN = os.environ.get(
    "DUCKLAKE_PG_DSN",
    "dbname=matthewmartin user=matthewmartin password=postgres host=127.0.0.1",
)

TOTAL_ROWS = 100_000
BATCH_SIZE = 10_000
MAX_WORKERS = 8

LAKE_ALIAS = "dl1"


# ---------------------------------------------------------------------------
# Connection helpers
# ---------------------------------------------------------------------------

def create_connection(*, initialize: bool = False) -> duckdb.DuckDBPyConnection:
    """
    Create an independent DuckDB instance and attach to the shared DuckLake.

    Every worker process calls this function, so no DuckDB connection objects
    are passed between processes.
    """
    con = duckdb.connect()

    con.execute("INSTALL aws; LOAD aws;")
    con.execute("INSTALL postgres; LOAD postgres;")
    con.execute("INSTALL ducklake; LOAD ducklake;")

    # Use the normal AWS credential chain: IAM role, environment variables,
    # ~/.aws credentials, etc.
    con.execute("""
        CREATE SECRET (
            TYPE s3,
            PROVIDER credential_chain,
            REGION 'us-east-1'
        )
    """)

    if initialize:
        # DATA_PATH is needed when the DuckLake is initially established.
        con.execute(f"""
            ATTACH 'ducklake:postgres:{PG_DSN}' AS {LAKE_ALIAS} (
                DATA_PATH '{S3_DATA_PATH}',
                DATA_INLINING_ROW_LIMIT 0
            )
        """)
    else:
        # Once the DuckLake exists, its data path is stored in the catalog.
        con.execute(
            f"ATTACH 'ducklake:postgres:{PG_DSN}' AS {LAKE_ALIAS}"
        )

    return con


# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

def initialize_ducklake() -> None:
    """
    Establish the DuckLake and create the target table before starting workers.
    """
    con = create_connection(initialize=True)

    con.execute(f"""
        CREATE TABLE IF NOT EXISTS {LAKE_ALIAS}.events (
            event_id BIGINT,
            batch_id INTEGER,
            event_ts TIMESTAMP,
            device_id VARCHAR,
            event_value DOUBLE
        )
    """)

    # Keep the example repeatable.
    con.execute(f"DELETE FROM {LAKE_ALIAS}.events")

    con.close()


# ---------------------------------------------------------------------------
# Worker
# ---------------------------------------------------------------------------

def write_batch(batch_id: int, start_row: int, row_count: int) -> dict:
    """
    Write one 10,000-row batch from an independent Python process.
    """
    started = time.perf_counter()

    con = create_connection()

    try:
        con.execute(
            f"""
            INSERT INTO {LAKE_ALIAS}.events
            SELECT
                i AS event_id,
                ? AS batch_id,
                current_timestamp AS event_ts,
                'device_' || CAST(i % 1000 AS VARCHAR) AS device_id,
                (i % 10000) * 0.01 AS event_value
            FROM range(?, ?) AS r(i)
            """,
            [
                batch_id,
                start_row,
                start_row + row_count,
            ],
        )

    finally:
        con.close()

    elapsed = time.perf_counter() - started

    return {
        "batch_id": batch_id,
        "rows": row_count,
        "seconds": elapsed,
        "pid": os.getpid(),
    }


# ---------------------------------------------------------------------------
# Main process
# ---------------------------------------------------------------------------

def main() -> None:
    initialize_ducklake()

    batches = []

    for batch_id, start_row in enumerate(
        range(0, TOTAL_ROWS, BATCH_SIZE),
        start=1,
    ):
        row_count = min(
            BATCH_SIZE,
            TOTAL_ROWS - start_row,
        )

        batches.append(
            (batch_id, start_row, row_count)
        )

    print(
        f"Writing {TOTAL_ROWS:,} rows "
        f"in {len(batches)} batches of {BATCH_SIZE:,}..."
    )

    wall_start = time.perf_counter()

    # Each 10,000-row batch becomes an independent task in the process pool.
    with ProcessPoolExecutor(max_workers=MAX_WORKERS) as executor:

        futures = [
            executor.submit(
                write_batch,
                batch_id,
                start_row,
                row_count,
            )
            for batch_id, start_row, row_count in batches
        ]

        for future in as_completed(futures):
            result = future.result()

            print(
                f"Batch {result['batch_id']:>2} | "
                f"{result['rows']:,} rows | "
                f"PID {result['pid']} | "
                f"{result['seconds']:.2f}s"
            )

    wall_seconds = time.perf_counter() - wall_start

    # Verify the shared DuckLake from the parent process.
    con = create_connection()

    total_rows = con.execute(
        f"""
        SELECT count(*)
        FROM {LAKE_ALIAS}.events
        """
    ).fetchone()[0]

    batch_counts = con.execute(
        f"""
        SELECT
            batch_id,
            count(*) AS row_count
        FROM {LAKE_ALIAS}.events
        GROUP BY batch_id
        ORDER BY batch_id
        """
    ).fetchall()

    con.close()

    print()
    print(f"Final row count: {total_rows:,}")
    print(f"Wall-clock time: {wall_seconds:.2f}s")
    print()

    for batch_id, row_count in batch_counts:
        print(
            f"Batch {batch_id:>2}: "
            f"{row_count:,} rows"
        )


if __name__ == "__main__":
    sys.exit(main())