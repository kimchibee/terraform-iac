#!/usr/bin/env bash
# discover-project-env.sh — Azure 구독에서 project_name / environment / location 및
# state backend RG/SA/Container 를 자동 탐지하여 source 가능한 export 라인을 출력.
#
# Pre-condition:
#   - scripts/import/env.sh 가 source 되어 있음 (AZ_SUB 사용)
#   - scripts/import/az-sp-login.sh 가 실행되어 az 세션이 있는 상태
#
# Usage:
#   eval "$(./scripts/import/discover-project-env.sh)"
#   ./scripts/import/discover-project-env.sh --human            # 추론 과정 + RG 목록 표시
#   ./scripts/import/discover-project-env.sh --project test     # 명시 override
#   ./scripts/import/discover-project-env.sh --rg test-x-x-rg   # 특정 RG 를 소스로 사용
#   ./scripts/import/discover-project-env.sh --pattern '-prod-' # 커스텀 RG name 패턴
#   ./scripts/import/discover-project-env.sh --subscription <id>
#
# 한계:
#   - leaf-specific 값(CIDR, VM size, NSG rules 등)은 이 스크립트로 추출하지 않음.
#     그 값들은 leaf 의 terraform.tfvars 에 두거나, terraform import 워크플로우로 state 에 들임.
set -uo pipefail

HUMAN="false"
SUB_OVERRIDE=""
PROJECT_OVERRIDE=""
ENV_OVERRIDE=""
LOCATION_OVERRIDE=""
RG_OVERRIDE=""
PATTERN="-x-x-"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --human)        HUMAN="true"; shift ;;
    --subscription) SUB_OVERRIDE="$2"; shift 2 ;;
    --project)      PROJECT_OVERRIDE="$2"; shift 2 ;;
    --environment)  ENV_OVERRIDE="$2"; shift 2 ;;
    --location)     LOCATION_OVERRIDE="$2"; shift 2 ;;
    --rg)           RG_OVERRIDE="$2"; shift 2 ;;
    --pattern)      PATTERN="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0" >&2; exit 2 ;;
    *)
      echo "ERROR: 알 수 없는 옵션: $1" >&2; exit 2 ;;
  esac
done

SUB="${SUB_OVERRIDE:-${AZ_SUB:-}}"
: "${SUB:?env.sh 를 먼저 source 하거나 --subscription <id> 전달}"

log() { [[ "$HUMAN" == "true" ]] && echo "[discover] $*" >&2 || true; }

log "subscription: $SUB"

# ─── 1) state backend SA 탐지 ────────────────────────────────────────────
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
  SA_JSON=$(az storage account list --subscription "$SUB" \
    --query "[?starts_with(name, 'tfstate')] | [0]" -o json 2>/dev/null || echo "null")
  if [[ "$SA_JSON" != "null" && -n "$SA_JSON" ]]; then
    BACKEND_SA=$(echo       "$SA_JSON" | jq -r '.name          // empty')
    BACKEND_RG=$(echo       "$SA_JSON" | jq -r '.resourceGroup // empty')
    BACKEND_LOCATION=$(echo "$SA_JSON" | jq -r '.location      // empty')
    log "state SA found by name pattern 'tfstate*': $BACKEND_SA"
  else
    log "state SA not found"
  fi
fi

# ─── 2) project / environment / location 탐지 ────────────────────────────
PROJECT=""
ENVIRON=""
LOCATION=""
SOURCE_RG=""

# (A) 명시 override 가장 우선
if [[ -n "$PROJECT_OVERRIDE" ]]; then
  PROJECT="$PROJECT_OVERRIDE"
  log "project_name override: $PROJECT"
fi
if [[ -n "$ENV_OVERRIDE" ]]; then
  ENVIRON="$ENV_OVERRIDE"
  log "environment override: $ENVIRON"
fi
if [[ -n "$LOCATION_OVERRIDE" ]]; then
  LOCATION="$LOCATION_OVERRIDE"
  log "location override: $LOCATION"
fi

# (B) --rg 로 특정 RG 지정 시 그 RG 에서 추출
if [[ -n "$RG_OVERRIDE" ]]; then
  RG_JSON=$(az group show --subscription "$SUB" --name "$RG_OVERRIDE" -o json 2>/dev/null || echo "null")
  if [[ "$RG_JSON" == "null" || -z "$RG_JSON" ]]; then
    echo "ERROR: --rg $RG_OVERRIDE 조회 실패 (존재하지 않거나 권한 없음)" >&2
    exit 3
  fi
  SOURCE_RG="$RG_OVERRIDE"
  [[ -z "$LOCATION" ]] && LOCATION=$(echo "$RG_JSON" | jq -r '.location')
  [[ -z "$PROJECT"  ]] && PROJECT=$(echo  "$RG_JSON" | jq -r '.tags.Project // .tags.project // empty')
  [[ -z "$ENVIRON"  ]] && ENVIRON=$(echo  "$RG_JSON" | jq -r '.tags.Environment // .tags.environment // empty')
  if [[ -z "$PROJECT" ]]; then
    # name pattern 매칭 (사용자 지정 RG 이름에서)
    PROJECT=$(echo "$SOURCE_RG" | sed -nE "s/^([a-z0-9]+).*$/\1/p")
  fi
  log "source RG (override): $SOURCE_RG → project='$PROJECT' env='$ENVIRON' loc='$LOCATION'"
fi

# (C) 자동 탐지 — tags.Project 가 있는 RG 들에서 unique 값 추출
if [[ -z "$PROJECT" ]]; then
  ALL_RGS_JSON=$(az group list --subscription "$SUB" -o json 2>/dev/null || echo "[]")
  UNIQUE_PROJECTS=$(echo "$ALL_RGS_JSON" | \
    jq -r '[.[] | (.tags.Project // .tags.project // empty)] | map(select(. != "")) | unique')
  PROJ_COUNT=$(echo "$UNIQUE_PROJECTS" | jq 'length')
  if [[ "$PROJ_COUNT" == "1" ]]; then
    PROJECT=$(echo "$UNIQUE_PROJECTS" | jq -r '.[0]')
    SOURCE_RG="(tags.Project from RGs)"
    log "project_name found via RG tags (unique): $PROJECT"
  elif [[ "$PROJ_COUNT" -gt 1 ]]; then
    log "RG tags.Project 에 여러 값 발견 — 자동 결정 불가:"
    echo "$UNIQUE_PROJECTS" | jq -r '.[]' | while read p; do log "  - $p"; done
    log "  --project <name> 으로 명시하세요"
  fi
fi

# (D) 자동 탐지 — name pattern 매칭 RG 의 첫 항목
if [[ -z "$PROJECT" ]]; then
  RG_JSON=$(az group list --subscription "$SUB" \
    --query "[?contains(name, '${PATTERN}')] | [0]" -o json 2>/dev/null || echo "null")
  if [[ "$RG_JSON" != "null" && -n "$RG_JSON" ]]; then
    SOURCE_RG=$(echo "$RG_JSON" | jq -r '.name')
    [[ -z "$LOCATION" ]] && LOCATION=$(echo "$RG_JSON" | jq -r '.location')
    [[ -z "$ENVIRON"  ]] && ENVIRON=$(echo  "$RG_JSON" | jq -r '.tags.Environment // .tags.environment // empty')
    # "<project>-x-x-rg" → "project"
    PROJECT=$(echo "$SOURCE_RG" | sed -nE "s/^([a-z0-9]+)${PATTERN}.*$/\1/p")
    if [[ -n "$PROJECT" ]]; then
      log "project_name found via name pattern '$PATTERN' on RG $SOURCE_RG: $PROJECT"
    else
      log "name pattern matched RG $SOURCE_RG 지만 prefix 추출 실패"
    fi
  else
    log "no RG matches pattern '$PATTERN'"
  fi
fi

# (E) location fallback: state RG/SA 에서
if [[ -z "$LOCATION" && -n "$BACKEND_LOCATION" ]]; then
  LOCATION="$BACKEND_LOCATION"
  log "location 을 state RG/SA 에서 보충: '$LOCATION'"
fi

# (F) environment default
[[ -z "$ENVIRON" ]] && ENVIRON="dev" && log "environment 기본값 'dev' 적용"

# ─── 3) --human 모드에서 보이는 RG 전체 목록 (진단용) ──────────────────────
if [[ "$HUMAN" == "true" ]]; then
  echo "" >&2
  echo "[discover] 이 구독에서 접근 가능한 RG 목록 (참고용):" >&2
  if [[ -z "${ALL_RGS_JSON:-}" ]]; then
    ALL_RGS_JSON=$(az group list --subscription "$SUB" -o json 2>/dev/null || echo "[]")
  fi
  RG_COUNT=$(echo "$ALL_RGS_JSON" | jq 'length')
  if [[ "$RG_COUNT" == "0" ]]; then
    echo "  (없음 — SP 에 구독 단위 Reader 권한이 없거나 RG 가 0개)" >&2
  else
    echo "$ALL_RGS_JSON" | jq -r '.[] | "  \(.name)  [\(.location)]  tags=\(.tags // {})"' >&2
  fi
  echo "" >&2
fi

# ─── 4) export 라인 출력 ──────────────────────────────────────────────────
echo "# Auto-discovered from subscription $SUB at $(date -u +%FT%TZ)"
[[ -n "$PROJECT"          ]] && echo "export TF_VAR_project_name='$PROJECT'"
[[ -n "$ENVIRON"          ]] && echo "export TF_VAR_environment='$ENVIRON'"
[[ -n "$LOCATION"         ]] && echo "export TF_VAR_location='$LOCATION'"
[[ -n "$BACKEND_RG"       ]] && echo "export TF_BACKEND_RG='$BACKEND_RG'"
[[ -n "$BACKEND_SA"       ]] && echo "export TF_BACKEND_SA='$BACKEND_SA'"
echo "export TF_BACKEND_CONTAINER='tfstate'"
echo "# 적용: eval \"\$(./scripts/import/discover-project-env.sh)\""

{
  [[ -z "$PROJECT"    ]] && {
    echo "WARN: project_name 추론 실패 — --human 으로 RG 목록 확인 후 다음 중 선택:" >&2
    echo "      ① --project <name>       명시 지정"                                   >&2
    echo "      ② --rg <rg-name>         특정 RG 에서 추출"                          >&2
    echo "      ③ --pattern <substring>  현재 '-x-x-' 외 다른 패턴 사용"             >&2
  }
  [[ -z "$LOCATION"   ]] && echo "WARN: location 추론 실패 — --location <name> 지정" >&2
  [[ -z "$BACKEND_SA" ]] && echo "WARN: state SA 미발견 — 00.state-backend bootstrap 필요할 수 있음" >&2
} || true
