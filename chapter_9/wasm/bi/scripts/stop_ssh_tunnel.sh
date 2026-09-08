#!/usr/bin/env bash
# Stops the SSH tunnel started by start_ssh_tunnel.sh.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pid_file="$(cd "$script_dir/.." && pwd)/data/ssh_tunnel.pid"

if [[ ! -f "$pid_file" ]]; then
  echo "No PID file found ($pid_file). Is the tunnel running?"
  exit 0
fi

pid="$(cat "$pid_file")"
if kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "Stopped SSH tunnel (PID $pid)."
else
  echo "Process $pid is not running (stale PID file)."
fi
rm -f "$pid_file"
