#!/bin/bash
# Container entrypoint — runs once per container start.
#
#   1. Create DuckLake + materialize to DuckDB  (skipped if already done)
#   2. Run Superset DB migrations
#   3. Create admin user                         (idempotent)
#   4. Initialise Superset roles & permissions
#   5. Start Superset via gunicorn (background)
#   6. Wait until healthy
#   7. Configure DB connection, datasets & charts via REST API (once)
#   8. Stay alive (forward signals to gunicorn)

set -euo pipefail

DATA_DIR=/data
INIT_FLAG="$DATA_DIR/.ducklake_pg_initialized"     # v2: PostgreSQL-catalog DuckLake
SETUP_FLAG="$DATA_DIR/.superset_json_metadata"     # v9: json_metadata positions PUT

# ── 1. Initialise DuckLake ───────────────────────────────────────────────────
if [ ! -f "$INIT_FLAG" ]; then
    echo "==> [1/7] Creating DuckLake with TPCH data (sf=0.001)..."
    python /scripts/init_ducklake.py
    touch "$INIT_FLAG"
    echo "==> DuckLake ready."
else
    echo "==> [1/7] DuckLake already initialised — skipping."
fi

# ── 2. Superset DB migrations ────────────────────────────────────────────────
echo "==> [2/7] Running Superset DB migrations..."
superset db upgrade

# ── 3. Create admin user ─────────────────────────────────────────────────────
echo "==> [3/7] Ensuring admin user exists..."
superset fab create-admin \
    --username  admin \
    --password  admin \
    --firstname Admin \
    --lastname  User \
    --email     admin@ducklake.local 2>/dev/null || true

# ── 4. Initialise roles & permissions ────────────────────────────────────────
echo "==> [4/7] Initialising Superset roles..."
superset init

# ── 5. Start Superset (background) ───────────────────────────────────────────
echo "==> [5/7] Starting Superset on :8088..."
gunicorn \
    --bind        0.0.0.0:8088 \
    --workers     2 \
    --worker-class gthread \
    --threads     10 \
    --timeout     120 \
    "superset.app:create_app()" &
GUNICORN_PID=$!

# Forward SIGTERM/SIGINT to gunicorn so Docker stop is clean
trap "kill $GUNICORN_PID 2>/dev/null; wait $GUNICORN_PID 2>/dev/null; exit 0" TERM INT

# ── 6. Wait for Superset to become healthy ────────────────────────────────────
echo "==> [6/7] Waiting for Superset to be ready..."
MAX_WAIT=180
WAITED=0
until curl -sf http://localhost:8088/health 2>/dev/null | grep -q "OK"; do
    sleep 3
    WAITED=$((WAITED + 3))
    if [ "$WAITED" -ge "$MAX_WAIT" ]; then
        echo "ERROR: Superset did not become healthy within ${MAX_WAIT}s"
        exit 1
    fi
done
echo "==> Superset is ready (after ${WAITED}s)!"

# ── 7. Configure database connection, datasets, and charts (once) ────────────
if [ ! -f "$SETUP_FLAG" ]; then
    echo "==> [7/7] Configuring DuckLake connection and charts..."
    python /scripts/setup_superset.py && touch "$SETUP_FLAG"
    echo "==> Configuration complete."
else
    echo "==> [7/7] Superset already configured — skipping."
fi

echo ""
echo "┌─────────────────────────────────────────────────┐"
echo "│  Superset → http://localhost:8088               │"
echo "│  Login:      admin / admin                      │"
echo "│  DB:         DuckLake TPCH (PostgreSQL catalog) │"
echo "│  Dashboard:  Dashboards → TPCH Analysis         │"
echo "└─────────────────────────────────────────────────┘"
echo ""

# Stay alive — wait for gunicorn to exit
wait $GUNICORN_PID
