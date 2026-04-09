#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# 목적: 모든 leaf 에 대해 terraform init + validate + plan 만 실행 (apply 없음)
# - bootstrap/backend/terraform.tfvars + HUB/SPOKE_SUBSCRIPTION_ID 환경변수 사용
# - leaf 의 terraform.tfvars 가 없으면 terraform.generated.auto.tfvars 자동 생성
# - 의존 stack 이 apply 되어 있지 않으면 plan 단계에서 remote_state 조회 실패하는
#   leaf 가 있을 수 있음 (init/validate 는 통과). 결과는 summary.tsv 로 정리.
# -----------------------------------------------------------------------------

set -uo pipefail
export TF_IN_AUTOMATION=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="$SCRIPT_DIR/logs/validate-$RUN_ID"
SUMMARY="$LOG_DIR/summary.tsv"

mkdir -p "$LOG_DIR"
echo -e "stack\tleaf\tinit\tvalidate\tplan\tlog" > "$SUMMARY"

if [[ ! -f "$BOOTSTRAP_TFVARS" ]]; then
  echo "ERROR: $BOOTSTRAP_TFVARS 없음"
  exit 1
fi

if [[ -z "${HUB_SUBSCRIPTION_ID:-}" || -z "${SPOKE_SUBSCRIPTION_ID:-}" ]]; then
  echo "ERROR: HUB_SUBSCRIPTION_ID / SPOKE_SUBSCRIPTION_ID 환경변수를 설정하세요."
  exit 1
fi

get_tfvar() {
  sed -nE "s/^[[:space:]]*${1}[[:space:]]*=[[:space:]]*\"?([^\"#]+)\"?.*$/\1/p" "$2" | head -n1 | xargs
}

BACKEND_RG=$(get_tfvar resource_group_name "$BOOTSTRAP_TFVARS")
BACKEND_SA=$(get_tfvar storage_account_name "$BOOTSTRAP_TFVARS")
BACKEND_CONTAINER=$(get_tfvar container_name "$BOOTSTRAP_TFVARS")
BACKEND_LOCATION=$(get_tfvar location "$BOOTSTRAP_TFVARS")

PROJECT_NAME=$(get_tfvar project_name "$REPO_ROOT/azure/dev/01.network/resource-group/hub-rg/terraform.tfvars" 2>/dev/null || true)
ENVIRONMENT_NAME=$(get_tfvar environment "$REPO_ROOT/azure/dev/01.network/resource-group/hub-rg/terraform.tfvars" 2>/dev/null || true)
LOCATION_NAME=$(get_tfvar location "$REPO_ROOT/azure/dev/01.network/resource-group/hub-rg/terraform.tfvars" 2>/dev/null || true)
NAME_PREFIX=$(get_tfvar name_prefix "$REPO_ROOT/azure/dev/03.shared-services/log-analytics/terraform.tfvars" 2>/dev/null || true)

[[ -z "$PROJECT_NAME" ]]    && PROJECT_NAME="test"
[[ -z "$ENVIRONMENT_NAME" ]] && ENVIRONMENT_NAME="dev"
[[ -z "$LOCATION_NAME" ]]   && LOCATION_NAME="$BACKEND_LOCATION"
[[ -z "$NAME_PREFIX" ]]     && NAME_PREFIX="${PROJECT_NAME}-x-x"

build_generated_tfvars_if_missing() {
  local leaf="$1"
  local out="$leaf/terraform.generated.auto.tfvars"
  [[ -f "$leaf/terraform.tfvars" ]] && { rm -f "$out"; return; }

  : > "$out"
  local any=0
  add_var() {
    local k="$1" v="$2"
    if grep -Rqs --include="*.tf" "variable[[:space:]]\\+\"${k}\"" "$leaf"; then
      printf '%s = "%s"\n' "$k" "$v" >> "$out"
      any=1
    fi
  }
  add_var "hub_subscription_id"          "$HUB_SUBSCRIPTION_ID"
  add_var "spoke_subscription_id"        "$SPOKE_SUBSCRIPTION_ID"
  add_var "project_name"                 "$PROJECT_NAME"
  add_var "environment"                  "$ENVIRONMENT_NAME"
  add_var "name_prefix"                  "$NAME_PREFIX"
  add_var "backend_resource_group_name"  "$BACKEND_RG"
  add_var "backend_storage_account_name" "$BACKEND_SA"
  add_var "backend_container_name"       "$BACKEND_CONTAINER"
  add_var "location"                     "$LOCATION_NAME"

  if grep -Rqs --include="*.tf" 'variable[[:space:]]\+"tags"' "$leaf"; then
    printf 'tags = {\n  Environment = "%s"\n  ManagedBy   = "Terraform"\n}\n' "$ENVIRONMENT_NAME" >> "$out"
    any=1
  fi
  [[ "$any" -ne 1 ]] && rm -f "$out"
}

az account set --subscription "$HUB_SUBSCRIPTION_ID" >/dev/null

STACKS=(01.network 02.storage 03.shared-services 04.apim 05.ai-services 06.compute 07.identity 08.rbac 09.connectivity)

for stack in "${STACKS[@]}"; do
  [[ -d "$REPO_ROOT/azure/dev/$stack" ]] || continue
  echo
  echo "########## $stack ##########"

  while IFS= read -r mf; do
    leaf="$(dirname "$mf")"
    [[ -f "$leaf/backend.tf" ]] || continue
    if [[ ! -f "$leaf/backend.hcl" ]]; then
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$stack" "${leaf#$REPO_ROOT/azure/dev/}" "skip" "skip" "skip" "no-backend.hcl" >> "$SUMMARY"
      echo "SKIP (no backend.hcl): ${leaf#$REPO_ROOT/azure/dev/}"
      continue
    fi

    leaf_id="$(echo "${leaf#$REPO_ROOT/azure/dev/}" | tr '/' '_')"
    log="$LOG_DIR/${stack}__${leaf_id}.log"
    init_s="-"; val_s="-"; plan_s="-"

    echo "===== ${leaf#$REPO_ROOT/azure/dev/} =====" | tee "$log"

    build_generated_tfvars_if_missing "$leaf"

    ( cd "$leaf" && terraform init -upgrade -backend-config=backend.hcl -input=false ) >>"$log" 2>&1 \
      && init_s="ok" || init_s="FAIL"

    if [[ "$init_s" == "ok" ]]; then
      ( cd "$leaf" && terraform validate ) >>"$log" 2>&1 \
        && val_s="ok" || val_s="FAIL"
    fi

    if [[ "$val_s" == "ok" ]]; then
      if [[ -f "$leaf/terraform.tfvars" ]]; then
        ( cd "$leaf" && terraform plan -input=false -lock=false -var-file=terraform.tfvars ) >>"$log" 2>&1 \
          && plan_s="ok" || plan_s="FAIL"
      else
        ( cd "$leaf" && terraform plan -input=false -lock=false ) >>"$log" 2>&1 \
          && plan_s="ok" || plan_s="FAIL"
      fi
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$stack" "${leaf#$REPO_ROOT/azure/dev/}" "$init_s" "$val_s" "$plan_s" "$log" >> "$SUMMARY"
    echo "  init=$init_s validate=$val_s plan=$plan_s"
  done < <(find "$REPO_ROOT/azure/dev/$stack" -type f -name "main.tf" | sort)
done

echo
echo "===== 요약 ====="
if command -v column >/dev/null 2>&1; then
  column -t -s $'\t' "$SUMMARY"
else
  cat "$SUMMARY"
fi
echo
echo "로그: $LOG_DIR"

# 종료 코드: init/validate 중 하나라도 FAIL 이면 1
if awk -F'\t' 'NR>1 && ($3=="FAIL" || $4=="FAIL") {f=1} END{exit !f}' "$SUMMARY"; then
  echo "ERROR: init/validate 단계 실패가 있습니다. 로그 확인 필요."
  exit 1
fi
echo "OK: 모든 leaf 의 init/validate 통과 (plan 실패는 의존 stack 미적용 영향일 수 있음)"
