#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# CI용: terraform.tfvars가 없는 leaf에 terraform.generated.auto.tfvars 생성
# 환경변수: HUB_SUBSCRIPTION_ID, SPOKE_SUBSCRIPTION_ID 등을 CI/CD Variables에서 주입
# ------------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"

get_tfvar_value() {
  local key="$1" file="$2"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"?([^\"#]+)\"?.*$/\1/p" "$file" | head -n1 | xargs
}

# Bootstrap 값 읽기
BACKEND_RG="$(get_tfvar_value "resource_group_name" "$BOOTSTRAP_TFVARS")"
BACKEND_SA="$(get_tfvar_value "storage_account_name" "$BOOTSTRAP_TFVARS")"
BACKEND_CONTAINER="$(get_tfvar_value "container_name" "$BOOTSTRAP_TFVARS")"
BACKEND_LOCATION="$(get_tfvar_value "location" "$BOOTSTRAP_TFVARS")"

# 기본값
PROJECT_NAME="${PROJECT_NAME:-test}"
ENVIRONMENT_NAME="${ENVIRONMENT_NAME:-dev}"
LOCATION_NAME="${LOCATION_NAME:-$BACKEND_LOCATION}"
NAME_PREFIX="${NAME_PREFIX:-${PROJECT_NAME}-x-x}"
HUB_SUBSCRIPTION_ID="${HUB_SUBSCRIPTION_ID:-}"
SPOKE_SUBSCRIPTION_ID="${SPOKE_SUBSCRIPTION_ID:-}"

generated_count=0

find "$REPO_ROOT/azure/dev" \
  -type d \( -name ".terraform" -o -name ".git" \) -prune -o \
  -type f -name "main.tf" -print0 | while IFS= read -r -d '' f; do

  leaf_abs="$(dirname "$f")"

  # backend.tf가 없으면 leaf가 아님 (예: 내부 modules/)
  [ -f "$leaf_abs/backend.tf" ] || continue

  # terraform.tfvars가 있으면 건너뜀
  [ -f "$leaf_abs/terraform.tfvars" ] && continue

  out="$leaf_abs/terraform.generated.auto.tfvars"
  : > "$out"
  any=0

  add_if_var_declared() {
    local var_name="$1" var_value="$2"
    if grep -Rqs --include="*.tf" "variable[[:space:]]\\+\"${var_name}\"" "$leaf_abs"; then
      printf '%s = "%s"\n' "$var_name" "$var_value" >> "$out"
      any=1
    fi
  }

  add_if_var_declared "hub_subscription_id" "$HUB_SUBSCRIPTION_ID"
  add_if_var_declared "spoke_subscription_id" "$SPOKE_SUBSCRIPTION_ID"
  add_if_var_declared "project_name" "$PROJECT_NAME"
  add_if_var_declared "environment" "$ENVIRONMENT_NAME"
  add_if_var_declared "name_prefix" "$NAME_PREFIX"
  add_if_var_declared "backend_resource_group_name" "$BACKEND_RG"
  add_if_var_declared "backend_storage_account_name" "$BACKEND_SA"
  add_if_var_declared "backend_container_name" "$BACKEND_CONTAINER"
  add_if_var_declared "location" "$LOCATION_NAME"

  if grep -Rqs --include="*.tf" "variable[[:space:]]\\+\"tags\"" "$leaf_abs"; then
    printf 'tags = {\n  Environment = "%s"\n  ManagedBy   = "Terraform"\n}\n' "$ENVIRONMENT_NAME" >> "$out"
    any=1
  fi

  if [ "$any" -ne 1 ]; then
    rm -f "$out"
  else
    generated_count=$((generated_count + 1))
    echo "[생성] $out"
  fi
done

echo "[완료] terraform.generated.auto.tfvars 생성: ${generated_count}개"
