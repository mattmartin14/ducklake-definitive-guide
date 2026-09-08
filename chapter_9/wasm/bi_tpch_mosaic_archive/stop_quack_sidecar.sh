#!/usr/bin/env bash
# Stops the Quack sidecar started by start_quack_sidecar.sh.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pid_file="$script_dir/data/quack_sidecar.pid"

if [[ ! -f "$pid_file" ]]; then
  echo "No PID file found ($pid_file). Is the sidecar running?"
  exit 0
fi

pid="$(cat "$pid_file")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "Stopped Quack sidecar (PID $pid)."
else
  echo "Process $pid is not running (stale PID file)."
fi
rm -f "$pid_file"
