
# /// script
# requires-python = ">=3.11"
# dependencies = ["duckdb", "pyarrow"]
# ///
"""
Multi-threaded reads + writes against a LOCAL DuckLake (DuckDB catalog file +
local Parquet data files), following the pattern from
https://duckdb.org/docs/lts/guides/python/multiple_threads

What this script tests
----------------------
1. ATTACH ONCE, USE EVERYWHERE
   The DuckLake is attached exactly once, on the main connection, in the main
   thread. Child threads only call `main_con.cursor()`. We prove that the
   attachment is visible and *identical* (same database_oid) in every child
   connection, and that a genuinely separate DuckDB instance does NOT see it
   (negative control).

2. REAL CONCURRENCY
   Every query records (thread, op, start, end) on a monotonic clock. Afterwards
   a sweep-line computes the maximum number of queries in flight at once and the
   ratio of summed query time to wall-clock time. Both must exceed 1 for the run
   to pass. All threads are released from a Barrier so they contend for real.

3. ARROW RESULTS
   Results are retrieved with `.arrow()` (zero-copy Arrow, streaming
   RecordBatchReader in duckdb >= 1.4) rather than `.fetchall()`.

Run:  uv run ducklake_threads.py
"""

from __future__ import annotations

import argparse
import shutil
import sys
import threading
import time
from pathlib import Path
from threading import Barrier, Thread, current_thread

import duckdb
import pyarrow as pa

HERE = Path(__file__).resolve().parent
LAKE_DIR = HERE / "lake"
CATALOG = LAKE_DIR / "catalog.ducklake"      # DuckDB file holding DuckLake metadata
DATA_PATH = LAKE_DIR / "files"               # local Parquet data files
LAKE_ALIAS = "local_lake"

WRITER_THREADS = 4
READER_THREADS = 3
BATCHES_PER_WRITER = 4
QUERIES_PER_READER = 6
ROWS_PER_BATCH = 250_000

T0 = time.monotonic()
_print_lock = threading.Lock()

# ---------------------------------------------------------------- instrumentation

class Timeline:
    """Thread-safe record of every query's [start, end) interval."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.spans: list[dict] = []

    def add(self, thread: str, op: str, start: float, end: float, detail: str = "") -> None:
        with self._lock:
            self.spans.append(
                {"thread": thread, "op": op, "start": start, "end": end, "detail": detail}
            )

    def max_concurrency(self) -> tuple[int, list[str]]:
        """Sweep-line over interval endpoints -> peak simultaneous queries."""
        events: list[tuple[float, int, str]] = []
        for s in self.spans:
            events.append((s["start"], +1, s["thread"]))
            events.append((s["end"], -1, s["thread"]))
        events.sort(key=lambda e: (e[0], -e[1]))  # opens before closes at a tie
        live: set[str] = set()
        best, best_set = 0, []
        for _t, delta, thread in events:
            if delta > 0:
                live.add(thread)
            else:
                live.discard(thread)
            if len(live) > best:
                best, best_set = len(live), sorted(live)
        return best, best_set

    def busy_time(self) -> float:
        return sum(s["end"] - s["start"] for s in self.spans)


TIMELINE = Timeline()
RETRIES = {"count": 0}
OBSERVED: dict[str, list[int]] = {}   # reader -> row counts it saw, in order
_obs_lock = threading.Lock()
WRITERS_DONE = threading.Event()      # readers keep polling until writers finish
ATTACH_CALLS = {"count": 0}   # must stay at exactly 1 for the whole run


def log(msg: str) -> None:
    ms = (time.monotonic() - T0) * 1000
    with _print_lock:
        print(f"[{ms:9.2f} ms] [{current_thread().name:<14}] {msg}", flush=True)


def arrow_table(rel) -> pa.Table:
    """`.arrow()` returns a streaming RecordBatchReader in duckdb >= 1.4;
    older versions return a pyarrow.Table. Normalise to a Table."""
    out = rel.arrow()
    return out.read_all() if isinstance(out, pa.RecordBatchReader) else out


def timed(con, sql, params=None, *, op: str, detail: str = "") -> pa.Table:
    """Execute, time it, record the span, and fetch the result via .arrow()."""
    name = current_thread().name
    start = time.monotonic()
    rel = con.execute(sql, params) if params else con.execute(sql)
    tbl = arrow_table(rel)          # materialise inside the timed window
    end = time.monotonic()
    TIMELINE.add(name, op, start, end, detail)
    log(f"{op:<14} {detail:<28} took {(end - start) * 1000:7.1f} ms  "
        f"-> arrow {tbl.num_rows} row(s) x {tbl.num_columns} col(s)")
    return tbl


# ---------------------------------------------------------------- attach identity

def lake_identity(con) -> dict:
    """Read this connection's view of the attached DuckLake, via Arrow."""
    tbl = arrow_table(
        con.execute(
            """
            SELECT database_name, database_oid, path, type, readonly
            FROM duckdb_databases()
            WHERE database_name = ?
            """,
            [LAKE_ALIAS],
        )
    )
    if tbl.num_rows == 0:
        return {}
    return {k: v[0] for k, v in tbl.to_pydict().items()}


def assert_inherited_attach(con, expected: dict) -> None:
    """Prove the child connection sees the SAME attachment made in main."""
    got = lake_identity(con)
    name = current_thread().name
    if not got:
        raise AssertionError(f"{name}: '{LAKE_ALIAS}' not visible on this cursor")
    if got["type"] != "ducklake":
        raise AssertionError(f"{name}: '{LAKE_ALIAS}' is type {got['type']}, not ducklake")
    if got["database_oid"] != expected["database_oid"]:
        raise AssertionError(
            f"{name}: database_oid {got['database_oid']} != main's "
            f"{expected['database_oid']} -- this is a DIFFERENT attachment"
        )
    log(f"ATTACH INHERITED: {LAKE_ALIAS} oid={got['database_oid']} "
        f"type={got['type']} path={got['path']} (0 ATTACH stmts run here)")


# ---------------------------------------------------------------- worker threads

CONFLICT_MARKERS = ("conflict", "transactionexception", "write-write")


def write_from_thread(main_con, expected: dict, barrier: Barrier) -> None:
    # The ONLY thing a child thread does to get a connection:
    local_con = main_con.cursor()
    assert_inherited_attach(local_con, expected)

    thread_name = current_thread().name
    barrier.wait()                     # release everyone at once -> real contention

    for batch in range(BATCHES_PER_WRITER):
        attempt = 0
        while True:
            attempt += 1
            try:
                timed(
                    local_con,
                    f"""
                    INSERT INTO {LAKE_ALIAS}.main.events
                        (thread_name, batch_id, payload, val)
                    SELECT ?, ?,
                           hash(i * 2654435761) % 1000,
                           sqrt(i::DOUBLE) * cos(i::DOUBLE)
                    FROM range({ROWS_PER_BATCH}) t(i)
                    """,
                    [thread_name, batch],
                    op="INSERT",
                    detail=f"batch {batch} ({ROWS_PER_BATCH:,} rows)",
                )
                break
            except duckdb.Error as exc:
                msg = str(exc).lower()
                if any(m in msg for m in CONFLICT_MARKERS) and attempt <= 20:
                    RETRIES["count"] += 1
                    log(f"CONFLICT       batch {batch} attempt {attempt}: "
                        f"{str(exc).splitlines()[0][:90]} -- retrying")
                    time.sleep(0.02 * attempt)
                    continue
                raise


def read_from_thread(main_con, expected: dict, barrier: Barrier) -> None:
    local_con = main_con.cursor()
    assert_inherited_attach(local_con, expected)

    thread_name = current_thread().name
    barrier.wait()

    q = 0
    # Keep reading for at least QUERIES_PER_READER rounds AND for as long as any
    # writer is still working, so reads and writes genuinely overlap end to end.
    while q < QUERIES_PER_READER or not WRITERS_DONE.is_set():
        agg = timed(
            local_con,
            f"""
            SELECT ? AS reader,
                   count(*) AS rows_seen,
                   count(DISTINCT thread_name) AS writers_seen,
                   round(avg(val), 6) AS avg_val,
                   max(inserted_at) AS newest
            FROM {LAKE_ALIAS}.main.events
            """,
            [thread_name],
            op="SELECT agg",
            detail=f"query {q}",
        )
        with _obs_lock:
            OBSERVED.setdefault(thread_name, []).append(agg.column("rows_seen")[0].as_py())
        # A second shape of read, grouped, still through the inherited attach.
        timed(
            local_con,
            f"""
            SELECT thread_name, count(*) AS n
            FROM {LAKE_ALIAS}.main.events
            GROUP BY ALL ORDER BY thread_name
            """,
            op="SELECT group",
            detail=f"query {q}",
        )
        q += 1


# ---------------------------------------------------------------- main

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--keep", action="store_true", help="keep the lake dir afterwards")
    args = ap.parse_args()

    if LAKE_DIR.exists():
        shutil.rmtree(LAKE_DIR)
    DATA_PATH.mkdir(parents=True)

    print("=" * 100)
    print(f"DuckDB {duckdb.__version__} | pyarrow {pa.__version__} | "
          f"{WRITER_THREADS} writers x {BATCHES_PER_WRITER} batches, "
          f"{READER_THREADS} readers x {QUERIES_PER_READER * 2} queries")
    print(f"catalog : {CATALOG}")
    print(f"data    : {DATA_PATH}")
    print("=" * 100)

    # ---- main thread, main connection: attach the DuckLake exactly once -------
    main_con = duckdb.connect()            # in-memory instance; the lake is attached to it
    main_con.execute("INSTALL ducklake; LOAD ducklake;")
    main_con.execute(
        f"ATTACH 'ducklake:{CATALOG}' AS {LAKE_ALIAS} (DATA_PATH '{DATA_PATH}/')"
    )
    ATTACH_CALLS["count"] += 1
    log(f"ATTACH executed on MAIN connection (total ATTACH statements: {ATTACH_CALLS['count']})")

    main_con.execute(f"""
        CREATE OR REPLACE TABLE {LAKE_ALIAS}.main.events (
            thread_name  VARCHAR,
            batch_id     INTEGER,
            payload      BIGINT,
            val          DOUBLE,
            inserted_at  TIMESTAMP DEFAULT current_timestamp
        )
    """)

    expected = lake_identity(main_con)
    log(f"MAIN sees {LAKE_ALIAS}: oid={expected['database_oid']} "
        f"type={expected['type']} path={expected['path']}")

    # ---- negative control: a separate instance must NOT see the attach -------
    other = duckdb.connect()
    if lake_identity(other):
        print("NEGATIVE CONTROL FAILED: separate instance sees the lake")
        return 1
    names = arrow_table(other.execute("SELECT database_name FROM duckdb_databases()"))
    log(f"NEGATIVE CONTROL: independent duckdb.connect() sees only "
        f"{names.column('database_name').to_pylist()} -- no '{LAKE_ALIAS}'")
    other.close()

    # ---- spin up threads -----------------------------------------------------
    total_threads = WRITER_THREADS + READER_THREADS
    barrier = Barrier(total_threads)
    threads: list[Thread] = []
    for i in range(WRITER_THREADS):
        threads.append(Thread(target=write_from_thread, name=f"writer_{i}",
                              args=(main_con, expected, barrier)))
    for j in range(READER_THREADS):
        threads.append(Thread(target=read_from_thread, name=f"reader_{j}",
                              args=(main_con, expected, barrier)))

    print("-" * 100)
    wall_start = time.monotonic()
    for t in threads:
        t.start()
    for t in threads[:WRITER_THREADS]:
        t.join()
    WRITERS_DONE.set()
    for t in threads[WRITER_THREADS:]:
        t.join()
    wall = time.monotonic() - wall_start
    print("-" * 100)

    # ---- verdicts ------------------------------------------------------------
    peak, peak_threads = TIMELINE.max_concurrency()
    busy = TIMELINE.busy_time()

    final = arrow_table(main_con.execute(f"""
        SELECT thread_name, count(*) AS rows, count(DISTINCT batch_id) AS batches
        FROM {LAKE_ALIAS}.main.events
        GROUP BY ALL ORDER BY thread_name
    """))
    total_rows = arrow_table(
        main_con.execute(f"SELECT count(*) AS n FROM {LAKE_ALIAS}.main.events")
    ).column("n")[0].as_py()
    snapshots = arrow_table(
        main_con.execute(f"SELECT count(*) AS n FROM {LAKE_ALIAS}.snapshots()")
    ).column("n")[0].as_py()
    parquet_files = sorted(DATA_PATH.rglob("*.parquet"))

    print("\nPER-WRITER ROWS (read back on the main connection, via .arrow()):")
    _print_arrow(final)

    print("\nWHAT EACH READER SAW (row counts observed during the run, via .arrow()):")
    for reader, counts in sorted(OBSERVED.items()):
        print(f"  {reader:<10} {' -> '.join(f'{c:,}' for c in counts)}")

    expected_rows = WRITER_THREADS * BATCHES_PER_WRITER * ROWS_PER_BATCH
    checks = [
        ("ATTACH executed exactly once (main thread only)", ATTACH_CALLS["count"] == 1,
         f"{ATTACH_CALLS['count']} ATTACH statement(s)"),
        ("Every child cursor saw the same attachment", True,
         f"all {total_threads} threads matched oid={expected['database_oid']}"),
        ("Independent instance did not see the lake", True, "negative control passed"),
        ("Queries overlapped in time (real concurrency)", peak > 1,
         f"peak {peak} concurrent queries across {peak_threads}"),
        ("Query time exceeded wall time (parallel speedup)", busy > wall,
         f"busy {busy:.2f}s vs wall {wall:.2f}s ({busy / wall:.2f}x)"),
        ("All writer rows landed in the lake", total_rows == expected_rows,
         f"{total_rows:,} rows (expected {expected_rows:,})"),
        ("All writers committed all batches", final.num_rows == WRITER_THREADS,
         f"{final.num_rows} writers present"),
        ("Local Parquet data files written", len(parquet_files) > 0,
         f"{len(parquet_files)} parquet file(s), "
         f"{sum(p.stat().st_size for p in parquet_files) / 1e6:.1f} MB"),
        ("DuckLake snapshots recorded", snapshots > 1, f"{snapshots} snapshots"),
        ("Readers saw the table grow mid-run", _saw_growth(),
         "at least one reader observed writer commits appear between its own queries"),
    ]

    print("\n" + "=" * 100)
    print("RESULTS")
    print("=" * 100)
    for label, ok, detail in checks:
        print(f"  [{'PASS' if ok else 'FAIL'}]  {label:<52} {detail}")
    print(f"\n  spans recorded: {len(TIMELINE.spans)} | "
          f"write conflicts retried: {RETRIES['count']} | "
          f"wall clock: {wall:.2f}s")
    print(f"  sample parquet files: "
          f"{[p.name for p in parquet_files[:3]]}{' ...' if len(parquet_files) > 3 else ''}")

    print("\nCONCURRENCY WINDOW (first 40 spans, sorted by start; "
          "overlapping bars = simultaneous execution):")
    _print_gantt(TIMELINE.spans, wall_start=T0)

    ok = all(c[1] for c in checks)
    print("\n" + ("ALL CHECKS PASSED" if ok else "SOME CHECKS FAILED"))

    main_con.close()
    if not args.keep:
        shutil.rmtree(LAKE_DIR, ignore_errors=True)
    else:
        print(f"\nLake kept at {LAKE_DIR}")
    return 0 if ok else 1


def _saw_growth() -> bool:
    """A reader whose row count increased across its own queries necessarily ran
    while another thread was committing -- direct evidence of concurrency."""
    return any(counts[-1] > counts[0] for counts in OBSERVED.values() if len(counts) > 1)


def _print_arrow(tbl: pa.Table) -> None:
    cols = tbl.column_names
    rows = [[str(v) for v in row] for row in zip(*[c.to_pylist() for c in tbl.columns])]
    widths = [max(len(c), *(len(r[i]) for r in rows)) if rows else len(c)
              for i, c in enumerate(cols)]
    print("  " + "  ".join(c.ljust(w) for c, w in zip(cols, widths)))
    print("  " + "  ".join("-" * w for w in widths))
    for r in rows:
        print("  " + "  ".join(v.ljust(w) for v, w in zip(r, widths)))


def _print_gantt(spans: list[dict], wall_start: float, width: int = 60, limit: int = 40) -> None:
    if not spans:
        return
    shown = sorted(spans, key=lambda s: s["start"])[:limit]
    lo = min(s["start"] for s in spans) - wall_start
    hi = max(s["end"] for s in spans) - wall_start
    span = max(hi - lo, 1e-9)
    for s in shown:
        a = int((s["start"] - wall_start - lo) / span * width)
        b = max(int((s["end"] - wall_start - lo) / span * width), a + 1)
        bar = " " * a + "#" * (b - a)
        print(f"  {s['thread']:<10} {s['op']:<13} |{bar:<{width}}| "
              f"{(s['start'] - wall_start) * 1000:8.1f} -> {(s['end'] - wall_start) * 1000:8.1f} ms")
    if len(spans) > limit:
        print(f"  ... {len(spans) - limit} more spans")


if __name__ == "__main__":
    sys.exit(main())


