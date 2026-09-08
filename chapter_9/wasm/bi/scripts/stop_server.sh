#!/usr/bin/env bash
# Stops the static server started by start_server.sh.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pid_file="$script_dir/../data/server.pid"

if [[ ! -f "$pid_file" ]]; then
  echo "No PID file found ($pid_file). Is the server running?"
  exit 0
fi

pid="$(cat "$pid_file")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "Stopped static server (PID $pid)."
else
  echo "Process $pid is not running (stale PID file)."
fi
rm -f "$pid_file"
