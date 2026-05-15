#!/usr/bin/env bash
# discover-project-env.sh — Azure 구독에서 project_name / environment / location 및
# state backend RG/SA/Container 를 자동 탐지하여 source 가능한 export 라인을 출력.
#
# Pre-condition:
#   - scripts/import/env.sh 가 source 되어 있음 (AZ_SUB 사용)
#   - scripts/import/az-sp-login.sh 가 실행되어 az 세션이 있는 상태
#
# Usage:
#   eval "$(./scripts/import/discover-project-env.sh)"           # 바로 적용
#   ./scripts/import/discover-project-env.sh                      # 출력만
#   ./scripts/import/discover-project-env.sh --human              # 추론 근거 + export 라인
#   ./scripts/import/discover-project-env.sh --subscription <id>  # 다른 구독에 대해
#
# 한계:
#   - leaf-specific 값(CIDR, VM size, NSG rules 등)은 이 스크립트로 추출하지 않음.
#     그 값들은 leaf 의 terraform.tfvars 에 두거나, terraform import 워크플로우로 state 에 들임.
set -uo pipefail

HUMAN="false"
SUB_OVERRIDE=""
for arg in "$@"; do
  case "$arg" in
    --human)        HUMAN="true" ;;
    --subscription) shift ;;   # consumed below; we look at positional
    -h|--help)      sed -n '2,15p' "$0" >&2; exit 2 ;;
  esac
done

# 간단한 --subscription <id> 파싱 (위 case 에서는 shift 가 문제라서 별도 처리)
for ((i=1; i<=$#; i++)); do
  if [[ "${!i}" == "--subscription" ]]; then
    j=$((i+1))
    SUB_OVERRIDE="${!j:-}"
  fi
done

SUB="${SUB_OVERRIDE:-${AZ_SUB:-}}"
: "${SUB:?env.sh 를 먼저 source 하거나 --subscription <id> 전달}"

log() { [[ "$HUMAN" == "true" ]] && echo "[discover] $*" >&2 || true; }

log "subscription: $SUB"

# ─── 1) state backend SA 탐지 (tags.Purpose=='tfstate') ──────────────────
SA_JSON=$(az storage account list --subscription "$SUB" \
  --query "[?tags.Purpose=='tfstate' || tags.purpose=='tfstate'] | [0]" \
  -o json 2>/dev/null || echo "null")

BACKEND_RG=""
BACKEND_SA=""
BACKEND_LOCATION=""
if [[ "$SA_JSON" != "null" && -n "$SA_JSON" ]]; then
  BACKEND_SA=$(echo       "$SA_JSON" | jq -r '.name             // empty')
  BACKEND_RG=$(echo       "$SA_JSON" | jq -r '.resourceGroup    // empty')
  BACKEND_LOCATION=$(echo "$SA_JSON" | jq -r '.location // .primaryLocation // empty')
  log "state SA found: $BACKEND_SA (RG=$BACKEND_RG, location=$BACKEND_LOCATION) via tag Purpose=tfstate"
else
  # fallback: 이름이 'tfstate' 로 시작하는 SA 첫 항목
  SA_JSON=$(az storage account list --subscription "$SUB" \
    --query "[?starts_with(name, 'tfstate')] | [0]" -o json 2>/dev/null || echo "null")
  if [[ "$SA_JSON" != "null" && -n "$SA_JSON" ]]; then
    BACKEND_SA=$(echo       "$SA_JSON" | jq -r '.name          // empty')
    BACKEND_RG=$(echo       "$SA_JSON" | jq -r '.resourceGroup // empty')
    BACKEND_LOCATION=$(echo "$SA_JSON" | jq -r '.location      // empty')
    log "state SA found by name pattern 'tfstate*': $BACKEND_SA"
  else
    log "state SA not found (no tag Purpose=tfstate, no name starting with 'tfstate')"
  fi
fi

# ─── 2) project / environment / location 탐지 ────────────────────────────
# 우선순위: project RG (이름 패턴 <p>-x-x-rg 또는 tags.Project) → state RG → 무
PROJECT=""
ENVIRON=""
LOCATION=""
SOURCE_RG=""

# (a) 이름에 '-x-x-' 포함 RG 첫 항목
RG_JSON=$(az group list --subscription "$SUB" \
  --query "[?contains(name, '-x-x-')] | [0]" -o json 2>/dev/null || echo "null")
if [[ "$RG_JSON" != "null" && -n "$RG_JSON" ]]; then
  SOURCE_RG=$(echo "$RG_JSON"  | jq -r '.name')
  LOCATION=$(echo  "$RG_JSON"  | jq -r '.location')
  PROJECT=$(echo   "$RG_JSON"  | jq -r '.tags.Project // .tags.project // empty')
  ENVIRON=$(echo   "$RG_JSON"  | jq -r '.tags.Environment // .tags.environment // empty')
  if [[ -z "$PROJECT" ]]; then
    # name pattern "test-x-x-rg" → "test"
    PROJECT=$(echo "$SOURCE_RG" | sed -nE 's/^([a-z0-9]+)-x-x-.*$/\1/p')
  fi
  log "project source RG: $SOURCE_RG (name pattern '-x-x-')"
  log "  project_name=$PROJECT  environment=${ENVIRON:-<unset>}  location='$LOCATION'"
fi

# (b) (a) 실패 시 state RG 로 location 만이라도 채움
if [[ -z "$LOCATION" && -n "$BACKEND_LOCATION" ]]; then
  LOCATION="$BACKEND_LOCATION"
  log "location 을 state RG/SA 에서 보충: '$LOCATION'"
fi

# (c) default
[[ -z "$ENVIRON" ]] && ENVIRON="dev" && log "environment 기본값 'dev' 적용 (RG tags 에 없음)"

# ─── 3) 출력 ──────────────────────────────────────────────────────────────
if [[ "$HUMAN" == "true" ]]; then
  echo "" >&2
  echo "# 다음을 셸에 적용하려면 eval 사용:" >&2
  echo "#   eval \"\$($0)\"  (--human 빼고)" >&2
fi

echo "# Auto-discovered from subscription $SUB at $(date -u +%FT%TZ)"
[[ -n "$PROJECT"          ]] && echo "export TF_VAR_project_name='$PROJECT'"
[[ -n "$ENVIRON"          ]] && echo "export TF_VAR_environment='$ENVIRON'"
[[ -n "$LOCATION"         ]] && echo "export TF_VAR_location='$LOCATION'"
[[ -n "$BACKEND_RG"       ]] && echo "export TF_BACKEND_RG='$BACKEND_RG'"
[[ -n "$BACKEND_SA"       ]] && echo "export TF_BACKEND_SA='$BACKEND_SA'"
echo "export TF_BACKEND_CONTAINER='tfstate'"
echo "# 적용: eval \"\$(./scripts/import/discover-project-env.sh)\""

# 경고
{
  [[ -z "$PROJECT"    ]] && echo "WARN: project_name 추론 실패 — 수동 export 필요" >&2
  [[ -z "$LOCATION"   ]] && echo "WARN: location 추론 실패 — 수동 export 필요"     >&2
  [[ -z "$BACKEND_SA" ]] && echo "WARN: state SA 미발견 — 00.state-backend bootstrap 필요할 수 있음" >&2
} || true
