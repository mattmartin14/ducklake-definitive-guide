import os
from sqlalchemy import event
from sqlalchemy.pool import Pool

# ── Security ──────────────────────────────────────────────────────────────────
# IMPORTANT: change this in any non-demo environment
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "ducklake-superset-demo-key")

# ── Superset metadata database (PostgreSQL) ───────────────────────────────────
SQLALCHEMY_DATABASE_URI = os.environ.get(
    "DATABASE_URL",
    "postgresql+psycopg2://superset:superset@db/superset",
)

# ── Cache (Redis) ─────────────────────────────────────────────────────────────
REDIS_URL = os.environ.get("REDIS_URL", "redis://redis:6379/0")

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_URL": REDIS_URL,
}
DATA_CACHE_CONFIG = CACHE_CONFIG

# ── Allow file-based / custom database connections (required for DuckDB) ──────
PREVENT_UNSAFE_DB_CONNECTIONS = False

# ── CSRF ──────────────────────────────────────────────────────────────────────
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = 60 * 60 * 24   # 24 hours

# ── Feature flags ─────────────────────────────────────────────────────────────
FEATURE_FLAGS: dict = {
    "ALERT_REPORTS": False,
    "DYNAMIC_PLUGINS": False,
    # Disables the localStorage→backend migration that causes `KeyError: 'dbId'`
    "SQLLAB_BACKEND_PERSISTENCE": False,
}

# ── DuckLake alias fix ────────────────────────────────────────────────────────
# Problem: when duckdb-engine connects with
#   duckdb:///ducklake:postgres:dbname=ducklake host=db ...
# DuckDB auto-names the attached catalog using the full connection string, so
# SQL Lab shows the ugly "postgres:dbname=ducklake host=db ..." as the schema.
#
# Fix: use duckdb:///:memory: as the URI and attach the DuckLake with a clean
# alias ("tpch") in a Pool connect event.  `USE tpch` then makes "tpch.main" the
# active catalog/schema, so queries just reference table names directly.

import logging as _logging
_dl_log = _logging.getLogger("superset.ducklake")

_DUCKLAKE_ATTACH = (
    "ducklake:postgres:dbname=ducklake host=db "
    "user=superset password=superset"
)


@event.listens_for(Pool, "connect")
def attach_ducklake(dbapi_connection, connection_record):
    """On every new DuckDB in-memory connection, attach the DuckLake as 'tpch'."""
    # duckdb-engine 0.13+ wraps the raw connection in ConnectionWrapper; check
    # the module name rather than the class name to handle both cases.
    if "duckdb" not in type(dbapi_connection).__module__:
        return  # ignore Postgres, Redis, and other non-DuckDB connections

    try:
        existing = {
            row[0]
            for row in dbapi_connection.execute(
                "SELECT database_name FROM duckdb_databases()"
            ).fetchall()
        }
        if "tpch" not in existing:
            dbapi_connection.execute("INSTALL ducklake; LOAD ducklake;")
            dbapi_connection.execute("INSTALL postgres;  LOAD postgres;")
            dbapi_connection.execute(
                f"ATTACH '{_DUCKLAKE_ATTACH}' AS tpch"
            )
        # Make tpch the active catalog so table names resolve without any prefix
        dbapi_connection.execute("USE tpch")
    except Exception as exc:
        print(f"[DUCKLAKE] ATTACH FAILED: {exc}", flush=True)

