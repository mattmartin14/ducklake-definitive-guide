#!/usr/bin/env python3
"""
Configures Superset via the REST API (v1) after it has started:
  - Database connection  → DuckLake TPCH  (duckdb:////data/tpch.duckdb)
  - Datasets             → orders, customer, lineitem, orders_with_customer
  - Charts               → 4 pre-built visualisations
  - Dashboard            → TPCH Analysis  (2 × 2 grid)

Run once; bootstrap.sh gates this with a flag file.
"""
import json
import sys
import time
import requests

BASE_URL    = "http://localhost:8088"
ADMIN_USER  = "admin"
ADMIN_PASS  = "admin"

# ── DuckLake connection (“the attach statement” as a SQLAlchemy URI) ────────────
# Reference: https://medium.com/data-analytics-at-nesta/ducklake-on-apache-superset-d1b1b00c222a
# duckdb-engine passes everything after duckdb:/// to duckdb.connect(), so DuckDB
# receives "ducklake:postgres:..." and auto-attaches the PostgreSQL-backed catalog.
DUCKLAKE_URI = "duckdb:///:memory:"

# superset_config.py attaches the DuckLake as 'tpch' (via a Pool connect event)
# and runs USE tpch, so queries just need: tpch.main.<table>
DUCKLAKE_SCHEMA = "tpch.main"


def ducklake_sql(table: str) -> str:
    """SELECT * from a DuckLake table — explicit catalog.schema prefix."""
    return f"SELECT * FROM {DUCKLAKE_SCHEMA}.{table}"


# ── Auth helpers ──────────────────────────────────────────────────────────────
# Superset's /api/v1/security/csrf_token/ endpoint requires the session cookie
# that the login response sets.  Using requests.Session() preserves that cookie
# automatically so that all subsequent calls (including the CSRF fetch) work.

def make_session() -> tuple[requests.Session, dict]:
    """Login and return (session, auth_headers) ready for API calls."""
    session = requests.Session()

    # 1. Login — the response also sets the session cookie we need for CSRF
    r = session.post(
        f"{BASE_URL}/api/v1/security/login",
        json={"username": ADMIN_USER, "password": ADMIN_PASS,
              "provider": "db", "refresh": True},
        timeout=30,
    )
    r.raise_for_status()
    token = r.json()["access_token"]

    # 2. Fetch CSRF token — session cookie from step 1 is sent automatically
    r = session.get(
        f"{BASE_URL}/api/v1/security/csrf_token/",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    r.raise_for_status()
    csrf = r.json()["result"]

    hdrs = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "X-CSRFToken": csrf,
        "Referer": BASE_URL,
    }
    session.headers.update(hdrs)
    return session, hdrs


# ── Database ──────────────────────────────────────────────────────────────────

def get_or_create_database(session: requests.Session) -> int:
    # Try to create
    payload = {
        "database_name": "DuckLake TPCH",
        # In-memory DuckDB; superset_config.py attaches the DuckLake as 'tpch'
        # on every new connection via a Pool connect event.
        "sqlalchemy_uri": DUCKLAKE_URI,
        "expose_in_sqllab": True,
        "allow_run_async": False,
    }
    r = session.post(f"{BASE_URL}/api/v1/database/", json=payload, timeout=30)
    if r.status_code in (200, 201):
        db_id = r.json()["id"]
        print(f"  ✓ database created  (id={db_id})")
        return db_id

    # Already exists → look it up
    q = json.dumps({"filters": [{"col": "database_name", "opr": "eq",
                                  "val": "DuckLake TPCH"}]})
    r2 = session.get(f"{BASE_URL}/api/v1/database/", params={"q": q}, timeout=10)
    r2.raise_for_status()
    results = r2.json().get("result", [])
    if results:
        db_id = results[0]["id"]
        print(f"  ✓ database already exists (id={db_id})")
        return db_id

    r.raise_for_status()   # surface the original error


# ── Datasets ──────────────────────────────────────────────────────────────────

def get_or_create_dataset(session: requests.Session, db_id: int,
                           name: str, sql: str | None = None) -> int | None:
    payload: dict = {"database": db_id, "schema": "main", "table_name": name}
    if sql:
        payload["sql"] = sql

    r = session.post(f"{BASE_URL}/api/v1/dataset/", json=payload, timeout=30)
    if r.status_code in (200, 201):
        ds_id = r.json()["id"]
        print(f"  ✓ dataset  '{name}' created (id={ds_id})")
        # Refresh so Superset fetches column names/types from DuckLake;
        # without this, chart plugins can't generate queries ("Empty query?").
        _refresh = session.put(f"{BASE_URL}/api/v1/dataset/{ds_id}/refresh", timeout=30)
        if _refresh.status_code == 200:
            print(f"  ✓ dataset  '{name}' columns synced")
        else:
            print(f"  ⚠ dataset  '{name}' column sync: {_refresh.status_code}")
        return ds_id

    # May already exist
    q = json.dumps({"filters": [{"col": "table_name", "opr": "eq", "val": name}]})
    r2 = session.get(f"{BASE_URL}/api/v1/dataset/", params={"q": q}, timeout=10)
    results = r2.json().get("result", [])
    if results:
        ds_id = results[0]["id"]
        print(f"  ✓ dataset  '{name}' exists  (id={ds_id})")
        return ds_id

    print(f"  ⚠ dataset  '{name}' failed: {r.status_code} {r.text[:120]}")
    return None


# ── Charts ────────────────────────────────────────────────────────────────────

def _metric(agg: str, col: str) -> dict:
    return {
        "aggregate": agg,
        "column": {"column_name": col},
        "expressionType": "SIMPLE",
        "label": f"{agg}({col})",
    }


def create_chart(session: requests.Session, name: str, viz_type: str,
                 ds_id: int, params: dict) -> int | None:
    payload = {
        "slice_name": name,
        "viz_type": viz_type,
        "datasource_id": ds_id,
        "datasource_type": "table",
        "params": json.dumps(params),
        "description": "",
    }
    r = session.post(f"{BASE_URL}/api/v1/chart/", json=payload, timeout=30)
    if r.status_code in (200, 201):
        cid = r.json()["id"]
        print(f"  ✓ chart    '{name}' created (id={cid})")
        return cid
    print(f"  ⚠ chart    '{name}' failed: {r.status_code} {r.text[:120]}")
    return None


# ── Dashboard ─────────────────────────────────────────────────────────────────

def create_dashboard(session: requests.Session, title: str, chart_ids: list[int]) -> int | None:
    """Build a 2-column grid layout and create the dashboard."""
    valid = [c for c in chart_ids if c is not None]

    # Two charts per row
    rows = [valid[i:i + 2] for i in range(0, len(valid), 2)]
    row_ids = [f"ROW_{i}" for i in range(len(rows))]

    layout: dict = {
        "DASHBOARD_VERSION_KEY": "v2",
        "ROOT_ID": {
            "children": ["GRID_ID"], "id": "ROOT_ID", "type": "ROOT",
        },
        "GRID_ID": {
            "children": row_ids, "id": "GRID_ID",
            "parents": ["ROOT_ID"],  "type": "GRID",
        },
    }

    for row_idx, (row_id, row_charts) in enumerate(zip(row_ids, rows)):
        block_ids = [f"CHART_{c}" for c in row_charts]
        layout[row_id] = {
            "children": block_ids, "id": row_id,
            "meta": {"background": "BACKGROUND_TRANSPARENT"},
            "parents": ["ROOT_ID", "GRID_ID"],
            "type": "ROW",
        }
        for chart_id in row_charts:
            layout[f"CHART_{chart_id}"] = {
                "children": [], "id": f"CHART_{chart_id}",
                "meta": {"chartId": chart_id, "height": 50, "width": 6},
                "parents": ["ROOT_ID", "GRID_ID", row_id],
                "type": "CHART",
            }

    payload = {
        "dashboard_title": title,
        "published": True,
        # Superset 4.x extracts chartIds from CHART nodes in position_json and
        # creates the dashboard_slices relationship automatically on save.
        # Do NOT pass a 'slices' field — it is rejected as "Unknown field."
        "position_json": json.dumps(layout),
    }
    r = session.post(f"{BASE_URL}/api/v1/dashboard/", json=payload, timeout=30)
    if r.status_code not in (200, 201):
        print(f"  ⚠ dashboard failed: {r.status_code} {r.text[:120]}")
        return None

    dash_id = r.json()["id"]
    print(f"  ✓ dashboard '{title}' created (id={dash_id})")

    # In Superset 4.x, the slice ↔ dashboard association (dashboard_slices table)
    # is only populated when UpdateDashboardCommand processes a PUT that includes
    # json_metadata with a 'positions' key.  The POST alone (even with
    # position_json) does not trigger set_dash_metadata, so charts render as
    # "no chart definition."  A follow-up PUT fixes this.
    put_r = session.put(
        f"{BASE_URL}/api/v1/dashboard/{dash_id}",
        json={"json_metadata": json.dumps({"positions": layout})},
        timeout=30,
    )
    if put_r.status_code == 200:
        print(f"  ✓ dashboard '{title}' slices linked")
    else:
        print(f"  ⚠ dashboard slice link: {put_r.status_code} {put_r.text[:120]}")

    return dash_id


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> None:
    print("Authenticating...")
    session, _hdrs = make_session()

    # ── Database ──────────────────────────────────────────────────────────────
    print("\n① Database connection")
    db_id = get_or_create_database(session)

    # ── Datasets ──────────────────────────────────────────────────────────────
    print("\n② Datasets")
    # All datasets are virtual SQL datasets so Superset resolves the full
    # DuckLake schema path through the duckdb-engine session.
    orders_id   = get_or_create_dataset(session, db_id, "orders",   sql=ducklake_sql("orders"))
    customer_id = get_or_create_dataset(session, db_id, "customer", sql=ducklake_sql("customer"))  # noqa: F841
    lineitem_id = get_or_create_dataset(session, db_id, "lineitem", sql=ducklake_sql("lineitem"))  # noqa: F841

    # Virtual dataset: orders joined to customer (both via full DuckLake path)
    oc_id = get_or_create_dataset(
        session, db_id, "orders_with_customer",
        sql=f"""
SELECT
    o.o_orderkey,
    o.o_orderdate,
    o.o_totalprice,
    o.o_orderstatus,
    o.o_orderpriority,
    c.c_name,
    c.c_mktsegment
FROM {DUCKLAKE_SCHEMA}.orders  o
JOIN {DUCKLAKE_SCHEMA}.customer c ON o.o_custkey = c.c_custkey
""",
    )

    # ── Charts ────────────────────────────────────────────────────────────────
    print("\n③ Charts")

    # 1. Pie – order status breakdown
    c1 = create_chart(session, "Order Status Breakdown", "pie", orders_id, {
        "viz_type": "pie",
        "groupby": ["o_orderstatus"],
        "metric": _metric("COUNT", "o_orderkey"),
        "row_limit": 50,
        "color_scheme": "bnbColors",
        "show_labels_threshold": 5,
        "show_legend": True,
        "label_type": "key_value",
        "outerRadius": 70,
    })

    # 2. Bar – total revenue by market segment
    # dist_bar is the reliable cross-version bar chart; echarts_bar may not be
    # bundled in all Superset 4.x builds and shows "viz type not supported"
    c2 = create_chart(session, "Revenue by Market Segment", "dist_bar", oc_id, {
        "viz_type": "dist_bar",
        "groupby": ["c_mktsegment"],
        "metrics": [_metric("SUM", "o_totalprice")],
        "row_limit": 20,
        "color_scheme": "bnbColors",
        "show_legend": False,
        "y_axis_label": "Revenue ($)",
    }) if oc_id else None

    # 3. Time-series line – monthly order revenue
    c3 = create_chart(session, "Monthly Order Revenue", "echarts_timeseries_line", orders_id, {
        "viz_type": "echarts_timeseries_line",
        "x_axis": "o_orderdate",
        "time_grain_sqla": "P1M",
        "metrics": [_metric("SUM", "o_totalprice")],
        "row_limit": 5000,
        "color_scheme": "bnbColors",
        "x_axis_title": "Month",
        "y_axis_title": "Revenue ($)",
        "show_legend": True,
        "smooth": True,
        "area": False,
    })

    # 4. Bar – order count by priority
    c4 = create_chart(session, "Order Count by Priority", "dist_bar", orders_id, {
        "viz_type": "dist_bar",
        "groupby": ["o_orderpriority"],
        "metrics": [_metric("COUNT", "o_orderkey")],
        "row_limit": 20,
        "color_scheme": "bnbColors",
        "show_legend": False,
        "y_axis_label": "Orders",
    })

    chart_ids = [c1, c2, c3, c4]

    # ── Dashboard ─────────────────────────────────────────────────────────────
    print("\n④ Dashboard")
    create_dashboard(session, "TPCH Analysis", chart_ids)

    print("""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  All done!
  → Open:       http://localhost:8088
  → Login:      admin / admin
  → Dashboard:  Dashboards → TPCH Analysis
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
""")


if __name__ == "__main__":
    main()
