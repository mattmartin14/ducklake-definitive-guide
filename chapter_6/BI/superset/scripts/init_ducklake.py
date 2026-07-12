#!/usr/bin/env python3
"""
Initialises a DuckLake that uses PostgreSQL as its catalog.

Architecture (per the Nesta / Medium tutorial):
  Catalog  → PostgreSQL  db:5432/ducklake     (metadata, table schemas, snapshots)
  Storage  → local disk  /data/parquet/        (TPC-H parquet files)
  Engine   → DuckDB  (via the ducklake extension)

Superset connects directly to the live DuckLake — no DuckDB file materialisation.
PostgreSQL handles concurrent readers, so all Superset workers can query together.

Connection string used everywhere:
  ducklake:postgres:dbname=ducklake host=db user=superset password=superset
"""
import os

import duckdb
import psycopg2
from psycopg2 import errors as pg_errors

DATA_DIR    = "/data"
PARQUET_DIR = f"{DATA_DIR}/parquet"

PG_HOST     = "db"
PG_PORT     = 5432
PG_USER     = "superset"
PG_PASSWORD = "superset"
PG_CATALOG  = "ducklake"    # DuckLake catalog database in PostgreSQL
PG_ADMIN_DB = "superset"    # connect here to CREATE DATABASE

DUCKLAKE_ATTACH = (
    f"ducklake:postgres:dbname={PG_CATALOG} host={PG_HOST} "
    f"user={PG_USER} password={PG_PASSWORD}"
)

TPCH_TABLES = [
    "customer", "lineitem", "nation",
    "orders",   "part",     "partsupp",
    "region",   "supplier",
]


def ensure_catalog_db() -> None:
    """Create the 'ducklake' PostgreSQL database if it doesn't exist yet."""
    conn = psycopg2.connect(
        host=PG_HOST, port=PG_PORT,
        user=PG_USER, password=PG_PASSWORD,
        database=PG_ADMIN_DB,
    )
    conn.autocommit = True
    cur = conn.cursor()
    try:
        cur.execute(f"CREATE DATABASE {PG_CATALOG}")
        cur.execute(f"GRANT ALL PRIVILEGES ON DATABASE {PG_CATALOG} TO {PG_USER}")
        print(f"  PostgreSQL database '{PG_CATALOG}' created.")
    except pg_errors.DuplicateDatabase:
        print(f"  PostgreSQL database '{PG_CATALOG}' already exists.")
    finally:
        cur.close()
        conn.close()


def ducklake_has_tables(con: duckdb.DuckDBPyConnection) -> bool:
    """True if TPC-H tables are already present in the DuckLake."""
    try:
        row = con.execute(
            "SELECT count(*) FROM tpch.information_schema.tables "
            "WHERE table_schema = 'main'"
        ).fetchone()
        return (row[0] if row else 0) > 0
    except Exception:
        return False


def main() -> None:
    os.makedirs(PARQUET_DIR, exist_ok=True)

    # 1. Make sure the catalog DB exists in PostgreSQL
    print("  Ensuring PostgreSQL catalog database exists...")
    ensure_catalog_db()

    # 2. Open DuckDB and attach the DuckLake (PostgreSQL-backed catalog)
    print("  Loading DuckDB extensions...")
    con = duckdb.connect()
    con.execute("INSTALL ducklake; LOAD ducklake;")
    con.execute("INSTALL postgres;  LOAD postgres;")
    con.execute("INSTALL tpch;      LOAD tpch;")

    print(f"  Attaching DuckLake → postgres://{PG_HOST}/{PG_CATALOG} ...")
    con.execute(f"ATTACH '{DUCKLAKE_ATTACH}' AS tpch (DATA_PATH '{PARQUET_DIR}/')")

    # 3. Populate TPC-H tables (idempotent)
    if ducklake_has_tables(con):
        print("  DuckLake already populated — skipping data generation.")
    else:
        print("  Generating TPC-H data (sf=0.001)...")
        con.execute("CALL dbgen(sf=0.001)")
        for table in TPCH_TABLES:
            print(f"    tpch.{table}")
            con.execute(f"CREATE TABLE tpch.{table} AS SELECT * FROM {table}")

    con.close()
    print(f"  Done.")
    print(f"    Catalog  → postgres://{PG_HOST}/{PG_CATALOG}")
    print(f"    Storage  → {PARQUET_DIR}/")
    print(f"    Attach   → {DUCKLAKE_ATTACH}")


if __name__ == "__main__":
    main()
