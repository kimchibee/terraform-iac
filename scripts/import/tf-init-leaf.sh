#!/usr/bin/env bash
set -euo pipefail

LEAF="${1:?leaf path required}"
KEY=$("$(dirname "$0")/tf-backend-key.sh" "$LEAF")

cd "$REPO_ROOT/$LEAF"
terraform init \
  -reconfigure \
  -backend-config="resource_group_name=$TF_BACKEND_RG" \
  -backend-config="storage_account_name=$TF_BACKEND_SA" \
  -backend-config="container_name=$TF_BACKEND_CONTAINER" \
  -backend-config="key=$KEY"
