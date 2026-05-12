#!/usr/bin/env bash
# Storage data-plane AAD 인증 오류
# ("www-authenticate header validation failed, issuer did not match") 진단
#
# Pre-condition:
#   - scripts/import/env.sh 가 source 되어 있음
#   - scripts/import/az-sp-login.sh 가 한 번 실행되어 az 세션이 있는 상태
#
# 출력:
#   1. 현재 az 세션 정보 (sub, tenant, identity)
#   2. Storage account 가 속한 구독과 그 구독의 AAD tenant
#   3. storage 데이터플레인용 OAuth 토큰의 iss/tid/aud
#   4. ARM_*/SUBSCRIPTION_ID env vars
#   5. 자동 비교 결과: token tid vs storage subscription tenant
set -uo pipefail

: "${TF_BACKEND_SA:?env.sh 를 먼저 source 하세요}"
: "${TF_BACKEND_RG:?env.sh 를 먼저 source 하세요}"

hr() { printf '%s\n' "----------------------------------------------------------------------"; }
title() { printf '\n[%s] %s\n' "$1" "$2"; hr; }

# ─── 1. 현재 az 세션 ──────────────────────────────────────────────────────
title 1/5 "현재 az 세션"
if ! az account show \
  --query '{subscription:name, subscription_id:id, tenant:tenantId, identity:user.name, type:user.type}' \
  -o json 2>/dev/null; then
  echo "ERROR: az 세션 없음. scripts/import/az-sp-login.sh 를 먼저 실행하세요."
  exit 1
fi

# ─── 2. Storage subscription 의 tenant ────────────────────────────────────
title 2/5 "Storage account 와 그 구독의 tenant"
SA_ID=$(az storage account show \
  -n "$TF_BACKEND_SA" -g "$TF_BACKEND_RG" \
  --query id -o tsv 2>/dev/null || true)

if [[ -z "$SA_ID" ]]; then
  echo "ERROR: storage account '$TF_BACKEND_SA' (RG=$TF_BACKEND_RG) 조회 실패"
  echo "       SP 가 해당 storage account 의 control-plane 권한(Reader 이상)이 있어야 함"
  exit 2
fi

SA_SUB=$(echo "$SA_ID" | awk -F/ '{print $3}')
echo "storage_account_id   = $SA_ID"
echo "storage_subscription = $SA_SUB"

STORAGE_TENANT=$(az account list \
  --query "[?id=='$SA_SUB'].tenantId" -o tsv 2>/dev/null || true)
if [[ -z "$STORAGE_TENANT" ]]; then
  echo "WARN: 'az account list' 에 storage 구독이 보이지 않음 (Lighthouse delegation 일 수 있음)"
  echo "     관리 포털 또는 'az account list --refresh' 로 확인 필요"
else
  echo "storage_tenant       = $STORAGE_TENANT"
fi

# ─── 3. Storage 데이터플레인 토큰의 iss/tid/aud ────────────────────────────
title 3/5 "Storage data-plane 토큰 디코드 (https://storage.azure.com/)"
TOKEN=$(az account get-access-token \
  --resource https://storage.azure.com/ \
  --query accessToken -o tsv 2>/dev/null || true)

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: storage scope 토큰 발급 실패. SP 가 storage data-plane 권한이 없거나"
  echo "       AAD 구성 문제일 수 있음."
  TOKEN_TID=""
else
  # JWT payload = 두 번째 segment. base64url → base64, 패딩 보정 후 디코드.
  PAYLOAD="${TOKEN#*.}"
  PAYLOAD="${PAYLOAD%.*}"
  PAYLOAD="${PAYLOAD//-/+}"
  PAYLOAD="${PAYLOAD//_//}"
  case $((${#PAYLOAD} % 4)) in
    2) PAYLOAD="${PAYLOAD}==" ;;
    3) PAYLOAD="${PAYLOAD}=" ;;
  esac
  DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null || true)
  if [[ -z "$DECODED" ]]; then
    echo "ERROR: JWT payload 디코드 실패 (base64 호환성 문제일 수 있음)"
    TOKEN_TID=""
  else
    if command -v jq >/dev/null 2>&1; then
      echo "$DECODED" | jq '{iss, tid, aud, appid, oid, upn, idtyp}'
      TOKEN_TID=$(echo "$DECODED" | jq -r '.tid // empty')
    else
      echo "$DECODED"
      TOKEN_TID=$(echo "$DECODED" | grep -oE '"tid":"[^"]+"' | cut -d'"' -f4 || true)
    fi
  fi
fi

# ─── 4. ARM_* / SUBSCRIPTION_ID env vars ─────────────────────────────────
title 4/5 "환경변수 상태"
printf "ARM_TENANT_ID        = %s\n" "${ARM_TENANT_ID:-<unset>}"
printf "ARM_SUBSCRIPTION_ID  = %s\n" "${ARM_SUBSCRIPTION_ID:-<unset>}"
printf "ARM_CLIENT_ID        = %s\n" "${ARM_CLIENT_ID:+<set:${#ARM_CLIENT_ID} chars>}${ARM_CLIENT_ID:-<unset>}"
printf "ARM_CLIENT_SECRET    = %s\n" "${ARM_CLIENT_SECRET:+<set:${#ARM_CLIENT_SECRET} chars>}${ARM_CLIENT_SECRET:-<unset>}"
printf "HUB_SUBSCRIPTION_ID  = %s\n" "${HUB_SUBSCRIPTION_ID:-<unset>}"
printf "SPOKE_SUBSCRIPTION_ID= %s\n" "${SPOKE_SUBSCRIPTION_ID:-<unset>}"
printf "AZ_SUB (env.sh)      = %s\n" "${AZ_SUB:-<unset>}"

# ─── 5. 자동 비교 / 판정 ──────────────────────────────────────────────────
title 5/5 "자동 비교 / 가설 판정"

VERDICT="UNKNOWN"
if [[ -n "$TOKEN_TID" && -n "$STORAGE_TENANT" ]]; then
  if [[ "$TOKEN_TID" == "$STORAGE_TENANT" ]]; then
    VERDICT="MATCH"
    echo "✓ Token tid ($TOKEN_TID) == storage subscription tenant"
    echo "  → issuer 불일치는 아님. 다른 원인 가능성:"
    echo "    • SP 가 storage 에 'Storage Blob Data *' RBAC 미보유 → 403 가 떠야 정상이지만 401 도 가능"
    echo "    • Storage account 의 'Allow Azure AD authorization' 설정 비활성"
    echo "    • Network ACL 로 IP 차단"
  else
    VERDICT="MISMATCH"
    echo "✗ Token tid ≠ storage subscription tenant — 가설 H1/H2 확정"
    echo "  Token tid       : $TOKEN_TID"
    echo "  Storage tenant  : $STORAGE_TENANT"
    echo ""
    echo "  해석:"
    if [[ -n "${ARM_TENANT_ID:-}" && "$ARM_TENANT_ID" != "$STORAGE_TENANT" ]]; then
      echo "    • ARM_TENANT_ID ($ARM_TENANT_ID) 는 SP 의 home tenant"
      echo "    • storage 구독은 다른 tenant ($STORAGE_TENANT) 에 있음"
      echo "    • Cross-tenant (Lighthouse/B2B) 시나리오 — data-plane AAD 인증 불가"
    fi
    echo ""
    echo "  권장 워크어라운드: ARM_ACCESS_KEY 사용 (control-plane 으로 키 fetch → 데이터플레인은 키)"
    echo "    export ARM_ACCESS_KEY=\"\$(az storage account keys list \\"
    echo "      -g \"\$TF_BACKEND_RG\" -n \"\$TF_BACKEND_SA\" --query '[0].value' -o tsv)\""
    echo "    az storage container show -n \"\$TF_BACKEND_CONTAINER\" -n \"\$TF_BACKEND_SA\" \\"
    echo "      --account-key \"\$ARM_ACCESS_KEY\" --query '{name:name}' -o table"
  fi
else
  echo "WARN: 비교 불가 (토큰 또는 storage tenant 조회 실패)"
  echo "      위 1~3 섹션 출력을 직접 확인하세요."
fi

hr
echo "Verdict: $VERDICT"
