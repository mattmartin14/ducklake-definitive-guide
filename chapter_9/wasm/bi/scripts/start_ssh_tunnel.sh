#!/usr/bin/env bash
# Opens a local SSH port-forward: localhost:$LOCAL_PORT -> EC2's quack port.
# Quack is plain HTTP with no public domain/TLS in front of it, so this
# tunnel is how both the browser (via serve.py's proxy) and native DuckDB
# clients reach it securely.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$(cd "$script_dir/../terraform" && pwd)"
data_dir="$(cd "$script_dir/.." && pwd)/data"
pid_file="$data_dir/ssh_tunnel.pid"
log_file="$data_dir/ssh_tunnel.log"

mkdir -p "$data_dir"

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if kill -0 "$existing_pid" 2>/dev/null; then
    echo "SSH tunnel is already running (PID $existing_pid). Nothing to do."
    exit 0
  fi
  echo "Removing stale PID file for dead process $existing_pid."
  rm -f "$pid_file"
fi

quack_ip="$(terraform -chdir="$terraform_dir" output -raw quack_public_ip)"
remote_port="$(terraform -chdir="$terraform_dir" output -raw quack_uri | sed -E 's/.*:([0-9]+)$/\1/')"
local_port="${LOCAL_PORT:-$remote_port}"
ssh_key="${SSH_KEY:-$HOME/.ssh/quack-poc}"

echo "Tunnelling localhost:$local_port -> $quack_ip:$remote_port"
ssh -i "$ssh_key" \
  -o ExitOnForwardFailure=yes \
  -o ServerAliveInterval=30 \
  -o StrictHostKeyChecking=accept-new \
  -N -L "127.0.0.1:${local_port}:127.0.0.1:${remote_port}" \
  "ubuntu@${quack_ip}" >"$log_file" 2>&1 &
tunnel_pid=$!
disown "$tunnel_pid" 2>/dev/null || true
echo "$tunnel_pid" >"$pid_file"

echo "SSH tunnel started in the background (PID $tunnel_pid)."
echo "Logs: $log_file"
echo "Stop with: ./scripts/stop_ssh_tunnel.sh (or: kill $tunnel_pid)"
