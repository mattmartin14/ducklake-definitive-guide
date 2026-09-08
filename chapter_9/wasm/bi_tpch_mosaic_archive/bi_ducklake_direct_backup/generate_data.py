"""Generate a small DuckLake catalog holding TPC-H tables for the WASM + Mosaic BI demo.

Run this once (or whenever you want to regenerate the data) with the project's
virtual environment activated:

    python chapter_9/wasm/bi/generate_data.py

It produces:
  - data/tpch_catalog.ducklake  (DuckLake catalog database, fetched by the browser)
  - data/tpch_data/             (Parquet files, served over HTTP and read via httpfs)
"""

import shutil
from pathlib import Path

import duckdb

BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
CATALOG_PATH = DATA_DIR / "tpch_catalog.ducklake"
STORAGE_DIR = DATA_DIR / "tpch_data"

# A handful of TPC-H tables, enough to build joins and aggregates for charts.
TABLES = ["customer", "orders", "lineitem", "nation", "region"]
SCALE_FACTOR = 0.001


def main() -> None:
    if DATA_DIR.exists():
        shutil.rmtree(DATA_DIR)
    DATA_DIR.mkdir(parents=True)

    con = duckdb.connect()
    con.execute("INSTALL ducklake")
    con.execute("INSTALL tpch")
    con.execute("LOAD ducklake")
    con.execute("LOAD tpch")

    con.execute(f"CALL dbgen(sf={SCALE_FACTOR})")

    con.execute(
        f"ATTACH 'ducklake:{CATALOG_PATH}' AS tpch_lake (DATA_PATH '{STORAGE_DIR}/')"
    )

    for table in TABLES:
        con.execute(f"CREATE OR REPLACE TABLE tpch_lake.{table} AS SELECT * FROM {table}")

    print("Row counts written to DuckLake:")
    for table in TABLES:
        (count,) = con.execute(f"SELECT count(*) FROM tpch_lake.{table}").fetchone()
        print(f"  {table}: {count} rows")

    con.close()
    print(f"\nDuckLake catalog: {CATALOG_PATH}")
    print(f"Parquet storage:  {STORAGE_DIR}")


if __name__ == "__main__":
    main()
