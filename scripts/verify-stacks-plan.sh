#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# 목적: AVM vendoring + ID 주입 작업 후, 각 스택을 의존성 순서대로
#       terraform init → validate → plan 까지 실행해 빠르게 검증한다.
#
# 동작:
#   - 실제 리소스를 만들지 않는다 (apply 없음)
#   - 각 리프에서: init -upgrade -backend-config=backend.hcl → validate → plan
#   - 결과는 scripts/logs/verify-<RUN_ID>/<리프>.log 에 저장
#   - 마지막에 init/validate/plan 단계별 PASS/FAIL 요약 표 출력
#
# 사용법:
#   ./scripts/verify-stacks-plan.sh                # 전체 의존성 순서로 검증
#   ./scripts/verify-stacks-plan.sh 01.network     # 특정 스택만 검증
#   ./scripts/verify-stacks-plan.sh --leaf azure/dev/01.network/vnet/hub-vnet
#                                                  # 단일 리프만 검증
#   ./scripts/verify-stacks-plan.sh --no-init      # init 생략 (기존 .terraform 재사용)
#
# 사전 조건:
#   - terraform CLI 설치
#   - az login 완료 (HUB_SUBSCRIPTION_ID 환경변수 권장)
#   - bootstrap/backend 가 이미 배포되어 backend storage가 존재
#   - 각 리프에 backend.hcl 또는 terraform.tfvars 가 준비됨
#     (없으면 deploy-stacks-sequential.sh 의 ensure_backend_hcl_for_leaves 를
#      먼저 실행하세요)
# -----------------------------------------------------------------------------

set -uo pipefail
export TF_IN_AUTOMATION=1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_ROOT="$SCRIPT_DIR/logs"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_LOG_DIR="$LOG_ROOT/verify-$RUN_ID"
SUMMARY_TSV="$RUN_LOG_DIR/verify-summary.tsv"
mkdir -p "$RUN_LOG_DIR"
printf "stack\tleaf\tinit\tvalidate\tplan\tlog\n" > "$SUMMARY_TSV"

DO_INIT=1
TARGET_STACK=""
TARGET_LEAF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-init)
      DO_INIT=0
      shift
      ;;
    --leaf)
      TARGET_LEAF="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '3,30p' "$0"
      exit 0
      ;;
    *)
      if [[ -z "$TARGET_STACK" ]]; then
        TARGET_STACK="$1"
      else
        echo "ERROR: 알 수 없는 인자: $1" >&2
        exit 2
      fi
      shift
      ;;
  esac
done

# -----------------------------------------------------------------------------
# 의존성 순서 (deploy-stacks-sequential.sh 와 동일)
# -----------------------------------------------------------------------------
STACK_ORDER=(
  "01.network"
  "02.storage"
  "03.shared-services"
  "04.apim"
  "05.ai-services"
  "06.compute"
  "07.identity"
  "08.rbac"
  "09.connectivity"
)

NETWORK_LEAF_ORDER=(
  "resource-group/hub-rg"
  "resource-group/spoke-rg"
  "vnet/hub-vnet"
  "vnet/spoke-vnet"
  "subnet/hub-gateway-subnet"
  "subnet/hub-dnsresolver-inbound-subnet"
  "subnet/hub-azurefirewall-subnet"
  "subnet/hub-azurefirewall-management-subnet"
  "subnet/hub-appgateway-subnet"
  "security-group/application-security-group/keyvault-clients"
  "security-group/application-security-group/vm-allowed-clients"
  "security-group/network-security-group/keyvault-standalone"
  "security-group/network-security-group/hub-pep"
  "security-group/network-security-group/hub-monitoring-vm"
  "security-group/network-security-group/spoke-pep"
  "subnet/hub-monitoring-vm-subnet"
  "subnet/hub-pep-subnet"
  "subnet/spoke-apim-subnet"
  "subnet/spoke-pep-subnet"
  "security-group/security-policy/hub-sg-policy-default"
  "security-group/security-policy/spoke-sg-policy-default"
  "route/hub-route-default"
  "route/spoke-route-default"
  "dns/private-dns-zone/hub-blob"
  "dns/private-dns-zone/hub-vault"
  "dns/private-dns-zone/spoke-openai"
  "dns/private-dns-zone/spoke-notebooks"
  "dns/private-dns-zone/spoke-ml"
  "dns/private-dns-zone/spoke-cognitiveservices"
  "dns/private-dns-zone/spoke-azure-api"
  "dns/private-dns-zone-vnet-link/hub-blob-to-hub-vnet"
  "dns/private-dns-zone-vnet-link/hub-vault-to-hub-vnet"
  "dns/private-dns-zone-vnet-link/hub-openai-to-hub-vnet"
  "dns/private-dns-zone-vnet-link/spoke-openai-to-spoke-vnet"
  "dns/private-dns-zone-vnet-link/spoke-notebooks-to-spoke-vnet"
  "dns/private-dns-zone-vnet-link/spoke-ml-to-spoke-vnet"
  "dns/private-dns-zone-vnet-link/spoke-cognitiveservices-to-spoke-vnet"
  "dns/private-dns-zone-vnet-link/spoke-azure-api-to-spoke-vnet"
  "dns/dns-private-resolver/hub"
  "public-ip/hub-vpn-gateway"
  "virtual-network-gateway/hub-vpn-gateway"
)

# -----------------------------------------------------------------------------
# 리프 디렉터리 수집 (backend.tf 가 있는 곳만 = 실제 plan 가능 리프)
# -----------------------------------------------------------------------------
collect_leaf_dirs() {
  local stack="$1"
  local stack_dir="$REPO_ROOT/azure/dev/$stack"
  [[ ! -d "$stack_dir" ]] && return

  find "$stack_dir" \
    -type d \( -name ".terraform" -o -name ".git" \) -prune -o \
    -type f -name "main.tf" -print0 | while IFS= read -r -d '' f; do
    local d
    d="$(dirname "$f")"
    [[ -f "$d/backend.tf" ]] && echo "$d"
  done | sort -u
}

collect_leaf_dirs_ordered() {
  local stack="$1"
  local stack_dir="$REPO_ROOT/azure/dev/$stack"

  if [[ "$stack" != "01.network" ]]; then
    collect_leaf_dirs "$stack"
    return
  fi

  # network는 NETWORK_LEAF_ORDER 우선
  local leaf
  for leaf in "${NETWORK_LEAF_ORDER[@]}"; do
    local abs="$stack_dir/$leaf"
    [[ -f "$abs/main.tf" && -f "$abs/backend.tf" ]] && echo "$abs"
  done

  # 목록에 없는 리프는 뒤에 자동 추가
  collect_leaf_dirs "$stack" | while IFS= read -r extra; do
    [[ -z "$extra" ]] && continue
    local rel="${extra#$stack_dir/}"
    local listed=0
    local item
    for item in "${NETWORK_LEAF_ORDER[@]}"; do
      [[ "$rel" == "$item" ]] && listed=1 && break
    done
    [[ "$listed" -eq 0 ]] && echo "$extra"
  done
}

# -----------------------------------------------------------------------------
# 단일 리프 검증
# -----------------------------------------------------------------------------
verify_leaf() {
  local stack="$1"
  local leaf_abs="$2"
  local leaf_rel="${leaf_abs#$REPO_ROOT/}"
  local leaf_id="${leaf_rel//\//__}"
  local log_file="$RUN_LOG_DIR/${leaf_id}.log"

  local init_status="SKIP"
  local validate_status="SKIP"
  local plan_status="SKIP"

  echo
  echo "===== [STACK: $stack] [LEAF: $leaf_rel] ====="
  echo "log: $log_file"

  if [[ ! -f "$leaf_abs/backend.hcl" && "$DO_INIT" -eq 1 ]]; then
    echo "WARN: backend.hcl 없음 → init 단계 SKIP" | tee "$log_file"
    init_status="NO_BACKEND_HCL"
    printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
      "$stack" "$leaf_rel" "$init_status" "$validate_status" "$plan_status" "$log_file" \
      >> "$SUMMARY_TSV"
    return
  fi

  (
    cd "$leaf_abs"

    if [[ "$DO_INIT" -eq 1 ]]; then
      echo "[1/3] terraform init -upgrade -backend-config=backend.hcl"
      terraform init -upgrade -backend-config=backend.hcl -input=false -no-color
      echo "[1/3] init OK"
    else
      echo "[1/3] init SKIP (--no-init)"
    fi

    echo "[2/3] terraform validate"
    terraform validate -no-color
    echo "[2/3] validate OK"

    echo "[3/3] terraform plan"
    if [[ -f "terraform.tfvars" ]]; then
      terraform plan -input=false -no-color -lock=false \
        -var-file=terraform.tfvars
    elif [[ -f "terraform.generated.auto.tfvars" ]]; then
      terraform plan -input=false -no-color -lock=false \
        -var-file=terraform.generated.auto.tfvars
    else
      terraform plan -input=false -no-color -lock=false
    fi
    echo "[3/3] plan OK"
  ) > "$log_file" 2>&1
  local rc=$?

  # 단계별 PASS/FAIL 추출
  if [[ "$DO_INIT" -eq 1 ]]; then
    if grep -q "\[1/3\] init OK" "$log_file"; then init_status="PASS"; else init_status="FAIL"; fi
  fi
  if grep -q "\[2/3\] validate OK" "$log_file"; then validate_status="PASS"; else validate_status="FAIL"; fi
  if grep -q "\[3/3\] plan OK" "$log_file"; then plan_status="PASS"; else plan_status="FAIL"; fi

  if [[ "$rc" -eq 0 ]]; then
    echo "  → init=$init_status validate=$validate_status plan=$plan_status"
  else
    echo "  → FAILED (init=$init_status validate=$validate_status plan=$plan_status)"
    echo "  → 마지막 20줄:"
    tail -20 "$log_file" | sed 's/^/    /'
  fi

  printf "%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$stack" "$leaf_rel" "$init_status" "$validate_status" "$plan_status" "$log_file" \
    >> "$SUMMARY_TSV"
}

# -----------------------------------------------------------------------------
# 메인
# -----------------------------------------------------------------------------
echo "[verify] RUN_ID=$RUN_ID"
echo "[verify] LOG_DIR=$RUN_LOG_DIR"
echo "[verify] DO_INIT=$DO_INIT"
[[ -n "$TARGET_STACK" ]] && echo "[verify] TARGET_STACK=$TARGET_STACK"
[[ -n "$TARGET_LEAF"  ]] && echo "[verify] TARGET_LEAF=$TARGET_LEAF"

if [[ -n "$TARGET_LEAF" ]]; then
  # 단일 리프 모드
  abs="$REPO_ROOT/${TARGET_LEAF#./}"
  abs="${abs%/}"
  if [[ ! -f "$abs/main.tf" ]]; then
    echo "ERROR: 리프 main.tf 없음: $abs" >&2
    exit 1
  fi
  stack_name="$(echo "${abs#$REPO_ROOT/azure/dev/}" | cut -d/ -f1)"
  verify_leaf "$stack_name" "$abs"
else
  for stack in "${STACK_ORDER[@]}"; do
    [[ -n "$TARGET_STACK" && "$TARGET_STACK" != "$stack" ]] && continue
    while IFS= read -r leaf_abs; do
      [[ -z "$leaf_abs" ]] && continue
      verify_leaf "$stack" "$leaf_abs"
    done < <(collect_leaf_dirs_ordered "$stack")
  done
fi

# -----------------------------------------------------------------------------
# 요약 출력
# -----------------------------------------------------------------------------
echo
echo "===== 검증 요약 ====="
column -t -s $'\t' "$SUMMARY_TSV" 2>/dev/null || cat "$SUMMARY_TSV"

total=$(($(wc -l < "$SUMMARY_TSV") - 1))
pass_plan=$(awk -F'\t' 'NR>1 && $5=="PASS"' "$SUMMARY_TSV" | wc -l)
fail_plan=$(awk -F'\t' 'NR>1 && $5=="FAIL"' "$SUMMARY_TSV" | wc -l)
fail_init=$(awk -F'\t' 'NR>1 && $3=="FAIL"' "$SUMMARY_TSV" | wc -l)
fail_validate=$(awk -F'\t' 'NR>1 && $4=="FAIL"' "$SUMMARY_TSV" | wc -l)

echo
echo "총 리프: $total"
echo "  init    FAIL: $fail_init"
echo "  validate FAIL: $fail_validate"
echo "  plan    FAIL: $fail_plan"
echo "  plan    PASS: $pass_plan"
echo
echo "상세 로그: $RUN_LOG_DIR"

if (( fail_init + fail_validate + fail_plan > 0 )); then
  exit 1
fi
