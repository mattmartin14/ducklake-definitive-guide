#!/usr/bin/env bash
# Deploys the Quack + DuckLake EC2 backend for this example.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$(cd "$script_dir/../terraform" && pwd)"

if [[ ! -f "$terraform_dir/terraform.tfvars" ]]; then
  echo "Missing terraform/terraform.tfvars. Copy terraform.tfvars.example and fill in your values first."
  exit 1
fi

terraform -chdir="$terraform_dir" init -input=false
terraform -chdir="$terraform_dir" apply -input=false "$@"

echo
echo "Quack public IP:  $(terraform -chdir="$terraform_dir" output -raw quack_public_ip)"
echo "Quack URI:        $(terraform -chdir="$terraform_dir" output -raw quack_uri)"
echo "DuckLake S3 path: $(terraform -chdir="$terraform_dir" output -raw ducklake_s3_uri)"
echo
echo "Next: wait ~1-2 minutes for cloud-init to finish, then run ./scripts/start_ssh_tunnel.sh"
