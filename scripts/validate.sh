#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
validation_dir=$(mktemp -d)
trap 'rm -rf "$validation_dir"' EXIT
terraform fmt -check -recursive
for environment in dev staging prod; do
  export TF_DATA_DIR="$validation_dir/$environment"
  terraform -chdir="environments/$environment" init -backend=false -input=false
  terraform -chdir="environments/$environment" validate
done
