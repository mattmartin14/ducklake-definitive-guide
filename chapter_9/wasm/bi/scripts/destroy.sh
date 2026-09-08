#!/usr/bin/env bash
# Tears down the Quack + DuckLake EC2 backend. Does NOT touch the shared
# S3 bucket (it's a data source, not a managed resource) or its data.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
terraform_dir="$(cd "$script_dir/../terraform" && pwd)"

terraform -chdir="$terraform_dir" destroy "$@"
