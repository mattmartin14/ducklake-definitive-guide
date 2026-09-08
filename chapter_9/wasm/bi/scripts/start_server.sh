#!/usr/bin/env bash
# Starts serve.py (static file server + Quack proxy) as a background daemon.
# Use stop_server.sh to release it.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_dir="$script_dir/../data"
pid_file="$data_dir/server.pid"
log_file="$data_dir/server.log"

mkdir -p "$data_dir"

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if kill -0 "$existing_pid" 2>/dev/null; then
    echo "Static server is already running (PID $existing_pid). Nothing to do."
    exit 0
  fi
  echo "Removing stale PID file for dead process $existing_pid."
  rm -f "$pid_file"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to run serve.py."
  exit 1
fi

export PORT="${PORT:-8000}"
export HOST="${HOST:-127.0.0.1}"

python3 "$script_dir/../serve.py" >"$log_file" 2>&1 &
server_pid=$!
disown "$server_pid" 2>/dev/null || true
echo "$server_pid" >"$pid_file"

echo "Static server started in the background (PID $server_pid) on http://$HOST:$PORT"
echo "Logs: $log_file"
echo "Stop with: ./scripts/stop_server.sh (or: kill $server_pid)"
