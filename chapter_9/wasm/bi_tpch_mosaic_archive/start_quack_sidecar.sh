#!/usr/bin/env bash
# Starts the local Quack sidecar as a background daemon: a native DuckDB
# process that owns the DuckLake catalog metadata (data/tpch_catalog.ducklake)
# and serves it over the Quack remote protocol on 127.0.0.1:9494 for
# DuckDB-WASM to attach to. Use stop_quack_sidecar.sh to release it.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_dir="$script_dir/data"
pid_file="$data_dir/quack_sidecar.pid"
log_file="$data_dir/quack_sidecar.log"

cd "$data_dir"

if [[ ! -f "tpch_catalog.ducklake" ]]; then
  echo "No DuckLake catalog found. Run 'python ../generate_data.py' first."
  exit 1
fi

if ! command -v duckdb >/dev/null 2>&1; then
  echo "duckdb CLI is required (brew install duckdb, or see https://duckdb.org/install)."
  exit 1
fi

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if kill -0 "$existing_pid" 2>/dev/null; then
    echo "Quack sidecar is already running (PID $existing_pid). Nothing to do."
    exit 0
  fi
  echo "Removing stale PID file for dead process $existing_pid."
  rm -f "$pid_file"
fi

export QUACK_TOKEN="${QUACK_TOKEN:-ducklake-demo-token}"

echo "Starting Quack sidecar on quack:127.0.0.1:9494 (token: $QUACK_TOKEN)"
echo "Serving DuckLake catalog: $data_dir/tpch_catalog.ducklake"

# `duckdb` reads from stdin as a REPL; `tail -f /dev/null` keeps stdin open
# (blocking forever, portable across macOS/Linux, unlike `sleep infinity`) so
# the CLI process (and the Quack listener it started) stays alive after
# running the -init script instead of exiting at EOF.
#
# The catalog file is opened directly as the positional database (not
# `:memory:`) so Quack serves its actual raw content (the existing TPC-H
# schema), not a fresh empty database.
#
# Backgrounding the whole pipeline with `&` makes `$!` resolve to the PID of
# the last command in the pipeline (duckdb itself) -- the exact process that
# holds the catalog file lock and the Quack listener, i.e. the one to kill.
tail -f /dev/null | duckdb -init "$script_dir/quack_sidecar.sql" "$data_dir/tpch_catalog.ducklake" >"$log_file" 2>&1 &
sidecar_pid=$!
disown "$sidecar_pid" 2>/dev/null || true
echo "$sidecar_pid" >"$pid_file"

echo "Quack sidecar started in the background (PID $sidecar_pid)."
echo "Logs: $log_file"
echo "Stop with: ./stop_quack_sidecar.sh (or: kill $sidecar_pid)"

