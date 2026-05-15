#!/usr/bin/env bash
# compare-leaf.sh — backend / state SA 없이 단일 leaf 의 코드 vs Azure 리소스 drift 체크
#
# 작동 원리:
#   - backend_override.tf 로 backend "local" 강제 (gitignore 의 *_override.tf 패턴에 매칭)
#   - imports.tf 로 단일 import 선언
#   - terraform init + plan 실행 (apply 없음 — read-only)
#   - EXIT trap 으로 임시 파일 모두 청소
#
# Pre-condition:
#   - scripts/import/env.sh 가 source 되어 있음
#   - ARM_* 환경변수 셋 (Terraform azurerm provider 가 자동 인식)
#   - leaf 가 terraform_remote_state 의존성을 갖지 않음
#     (있으면 init/plan 단계에서 실패 — 의존 없는 leaf 만 권장)
#
# Usage:
#   ./scripts/import/compare-leaf.sh <leaf_path> <azure_resource_id> <tf_address> [--keep]
#
# Example:
#   ./scripts/import/compare-leaf.sh \
#     azure/hub/01.network/resource-group/hub-rg \
#     "/subscriptions/<sub>/resourceGroups/test-x-x-rg" \
#     "module.resource_group.azurerm_resource_group.this"
#
# Exit codes:
#   0  Verdict 출력 후 정상 종료 (MATCH / DRIFT / WRONG_IMPORT / NO_CHANGES)
#   2  사용법 오류
#   3  leaf 경로/main.tf 없음
#   4  기존 imports.tf 존재 (다른 작업 충돌)
#   5  terraform init 실패
#   기타  terraform plan 실패 그대로 전파

set -uo pipefail

usage() {
  cat >&2 <<EOF
Usage: $0 <leaf_path> <azure_resource_id> <tf_address> [--keep]

Args:
  leaf_path           e.g. azure/hub/01.network/resource-group/hub-rg
  azure_resource_id   e.g. /subscriptions/<sub>/resourceGroups/test-x-x-rg
  tf_address          e.g. module.resource_group.azurerm_resource_group.this

Options:
  --keep   임시 파일(backend_override.tf / imports.tf / .terraform/ / state)을 청소하지 않음
EOF
  exit 2
}

KEEP="false"
POS=()
for arg in "$@"; do
  case "$arg" in
    --keep)    KEEP="true" ;;
    -h|--help) usage ;;
    *)         POS+=("$arg") ;;
  esac
done

[[ ${#POS[@]} -eq 3 ]] || usage

LEAF="${POS[0]}"
AZURE_ID="${POS[1]}"
TF_ADDR="${POS[2]}"

: "${REPO_ROOT:?env.sh 를 먼저 source 하세요}"

LEAF_DIR="$REPO_ROOT/$LEAF"
[[ -d "$LEAF_DIR"        ]] || { echo "ERROR: leaf 디렉토리 없음: $LEAF_DIR"        >&2; exit 3; }
[[ -f "$LEAF_DIR/main.tf" ]] || { echo "ERROR: $LEAF/main.tf 없음 (leaf 가 아님)" >&2; exit 3; }

BACKEND_OVR="$LEAF_DIR/backend_override.tf"
IMPORTS_TF="$LEAF_DIR/imports.tf"

# 기존 imports.tf 가 있으면 다른 작업 충돌 의심 — 사용자 결정 필요
if [[ -f "$IMPORTS_TF" ]]; then
  echo "ERROR: $IMPORTS_TF 가 이미 존재합니다 — 다른 작업 진행 중일 수 있음." >&2
  echo "       해당 파일 검토 후 수동 제거하고 다시 실행하세요."             >&2
  exit 4
fi

# 청소 함수 — EXIT trap 에서 호출. 어떤 종료 사유든 임시 파일을 정리
cleanup() {
  if [[ "$KEEP" == "true" ]]; then
    echo
    echo "[compare-leaf] --keep 모드: 다음 파일을 남깁니다 (수동 정리 필요):"
    echo "  $BACKEND_OVR"
    echo "  $IMPORTS_TF"
    echo "  $LEAF_DIR/.terraform/, .terraform.lock.hcl, terraform.tfstate*"
    return 0
  fi
  echo
  echo "[compare-leaf] 임시 파일 정리..."
  rm -rf "$LEAF_DIR/.terraform" "$LEAF_DIR/.terraform.lock.hcl"
  rm -f  "$LEAF_DIR/terraform.tfstate" "$LEAF_DIR/terraform.tfstate.backup"
  rm -f  "$LEAF_DIR/plan.out"
  rm -f  "$BACKEND_OVR" "$IMPORTS_TF"
  echo "[compare-leaf] 정리 완료. Azure 무변경, git 추적 파일 무변경."
}
trap cleanup EXIT

echo "[compare-leaf] $LEAF"
echo "  azure resource_id : $AZURE_ID"
echo "  tf address        : $TF_ADDR"

# 1) backend "local" override (gitignored: *_override.tf)
cat > "$BACKEND_OVR" <<'EOF'
# 임시 — scripts/import/compare-leaf.sh 가 자동 생성/제거.
# gitignore 의 *_override.tf 패턴에 매칭되어 추적되지 않음.
terraform {
  backend "local" {}
}
EOF

# 2) imports.tf
cat > "$IMPORTS_TF" <<EOF
# 임시 — scripts/import/compare-leaf.sh 가 자동 생성/제거.
import {
  id = "$AZURE_ID"
  to = $TF_ADDR
}
EOF

# 3) terraform init (local backend)
cd "$LEAF_DIR"
echo
echo "[compare-leaf] terraform init (local backend)..."
INIT_LOG="$(mktemp -t compare-leaf-init.XXXXXX)"
if ! terraform init -input=false -no-color > "$INIT_LOG" 2>&1; then
  echo "ERROR: terraform init 실패. 마지막 30 라인:" >&2
  tail -30 "$INIT_LOG" >&2
  rm -f "$INIT_LOG"
  exit 5
fi
rm -f "$INIT_LOG"
echo "  OK"

# 4) terraform plan
echo
echo "[compare-leaf] terraform plan..."
PLAN_LOG="$(mktemp -t compare-leaf-plan.XXXXXX)"
terraform plan -input=false -no-color -out=plan.out 2>&1 | tee "$PLAN_LOG"
PLAN_RC=${PIPESTATUS[0]}

if [[ $PLAN_RC -ne 0 ]]; then
  echo
  echo "[compare-leaf] PLAN_ERROR (terraform plan exit=$PLAN_RC)" >&2
  echo "  - terraform_remote_state 의존성 보유 leaf 라면 이 스크립트로는 불가" >&2
  echo "  - import 주소 또는 azure resource_id 오류 가능성도 확인"           >&2
  rm -f "$PLAN_LOG"
  exit $PLAN_RC
fi

# 5) Verdict 추출
echo
SUMMARY=$(grep -E '^Plan: ' "$PLAN_LOG" | head -1 || true)
HAS_NO_CHANGES=$(grep -c 'No changes' "$PLAN_LOG" || true)
rm -f "$PLAN_LOG"

if [[ -n "$SUMMARY" ]]; then
  echo "[compare-leaf] $SUMMARY"
  if   echo "$SUMMARY" | grep -qE '1 to import, 0 to add, 0 to change, 0 to destroy'; then
    echo "Verdict: MATCH         코드 ↔ Azure 일치"
  elif echo "$SUMMARY" | grep -qE 'to destroy'; then
    echo "Verdict: WRONG_IMPORT  destroy 가 보임 — import 주소 또는 azure resource_id 검토 필요"
  else
    echo "Verdict: DRIFT         속성 차이 존재. 위 plan 출력에서 ~ 마크 라인 확인"
  fi
elif [[ "$HAS_NO_CHANGES" -gt 0 ]]; then
  echo "Verdict: NO_CHANGES    plan 에 변경 없음 (예상 외 케이스)"
else
  echo "Verdict: UNKNOWN       'Plan: ...' 라인을 찾지 못함. 위 출력을 직접 검토"
fi
