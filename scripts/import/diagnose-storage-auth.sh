#!/usr/bin/env bash
# Storage account 접근/RBAC 진단 + 부족 권한 부여 명령 생성
#
# Pre-condition:
#   - scripts/import/env.sh 가 source 되어 있음
#   - scripts/import/az-sp-login.sh 가 실행되어 az 세션이 있는 상태 (없어도 일부 출력은 가능)
#
# 진단 흐름:
#   [1] 현재 인증 신원 (account + Object ID + principal type)
#   [2] Storage account 존재 / control-plane 접근 확인
#   [3] (선택) Storage subscription tenant — issuer 불일치 비교용
#   [4] (선택) Data-plane 토큰 decode (iss/tid)
#   [5] 현재 신원의 RBAC 권한 분석 (SA scope, 상속 포함)
#   [6] 부족 권한 판정 + 관리자에게 보낼 부여 명령 출력
set -uo pipefail

: "${TF_BACKEND_SA:?env.sh 를 먼저 source 하세요}"
: "${TF_BACKEND_RG:?env.sh 를 먼저 source 하세요}"
: "${AZ_SUB:?env.sh 를 먼저 source 하세요}"

# Scope ID 사전 구성 (storage account show 가 실패해도 RBAC 조회는 가능)
SUB_SCOPE="/subscriptions/$AZ_SUB"
RG_SCOPE="${SUB_SCOPE}/resourceGroups/${TF_BACKEND_RG}"
SA_SCOPE="${RG_SCOPE}/providers/Microsoft.Storage/storageAccounts/${TF_BACKEND_SA}"

hr()    { printf '%s\n' "----------------------------------------------------------------------"; }
title() { printf '\n[%s] %s\n' "$1" "$2"; hr; }

# ──────────────────────────────────────────────────────────────────────────
# [1] 현재 인증 신원
# ──────────────────────────────────────────────────────────────────────────
title 1/6 "현재 az 세션 신원"
ACCOUNT_JSON=$(az account show -o json 2>/dev/null || true)
if [[ -z "$ACCOUNT_JSON" ]]; then
  echo "ERROR: az 세션 없음. ./scripts/import/az-sp-login.sh 를 먼저 실행하세요."
  exit 1
fi

CURRENT_SUB=$(echo "$ACCOUNT_JSON"     | jq -r '.id')
CURRENT_TENANT=$(echo "$ACCOUNT_JSON"  | jq -r '.tenantId')
CURRENT_USER_NAME=$(echo "$ACCOUNT_JSON" | jq -r '.user.name')
CURRENT_USER_TYPE=$(echo "$ACCOUNT_JSON" | jq -r '.user.type')

echo "subscription   : $(echo "$ACCOUNT_JSON" | jq -r '.name') ($CURRENT_SUB)"
echo "tenant         : $CURRENT_TENANT"
echo "identity       : $CURRENT_USER_NAME"
echo "identity type  : $CURRENT_USER_TYPE"

# 현재 신원의 Object ID + 표시명 + principal type (RBAC 부여/조회의 키)
ASSIGNEE_OID=""
ASSIGNEE_DISPLAY=""
ASSIGNEE_TYPE=""
case "$CURRENT_USER_TYPE" in
  servicePrincipal)
    # az login --service-principal 일 때 user.name == Application/Client ID
    SP_CLIENT_ID="$CURRENT_USER_NAME"
    ASSIGNEE_OID=$(az ad sp show --id "$SP_CLIENT_ID" --query id -o tsv 2>/dev/null || true)
    SP_DISPLAY=$(az ad sp show --id "$SP_CLIENT_ID" --query displayName -o tsv 2>/dev/null || echo "(displayName 조회 실패)")
    if [[ -z "$ASSIGNEE_OID" ]]; then
      echo "WARN : Graph API 차단으로 Object ID 조회 실패. ARM_CLIENT_ID 를 그대로 assignee 로 사용."
      ASSIGNEE_OID="$SP_CLIENT_ID"   # az role assignment list 는 ClientID 도 받음 (Graph 호출 필요)
    fi
    ASSIGNEE_DISPLAY="$SP_DISPLAY"
    ASSIGNEE_TYPE="ServicePrincipal"
    echo "Service Principal:"
    echo "  Client ID    : $SP_CLIENT_ID"
    echo "  Object ID    : $ASSIGNEE_OID"
    echo "  Display Name : $SP_DISPLAY"
    ;;
  user)
    ASSIGNEE_OID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)
    ASSIGNEE_DISPLAY="$CURRENT_USER_NAME"
    ASSIGNEE_TYPE="User"
    echo "User account:"
    echo "  UPN          : $CURRENT_USER_NAME"
    echo "  Object ID    : ${ASSIGNEE_OID:-<조회 실패>}"
    ;;
  *)
    echo "WARN : 알 수 없는 identity type ($CURRENT_USER_TYPE) — principal-type 을 ServicePrincipal 로 가정"
    ASSIGNEE_OID="$CURRENT_USER_NAME"
    ASSIGNEE_DISPLAY="$CURRENT_USER_NAME"
    ASSIGNEE_TYPE="ServicePrincipal"
    ;;
esac

# ──────────────────────────────────────────────────────────────────────────
# [2] Storage account 존재 / control-plane 접근
# ──────────────────────────────────────────────────────────────────────────
title 2/6 "Storage account control-plane 접근"
SA_SHOW_OUT=$(az storage account show \
  -n "$TF_BACKEND_SA" -g "$TF_BACKEND_RG" --subscription "$AZ_SUB" \
  -o json 2>&1 || true)

SA_ACCESS="UNKNOWN"
if echo "$SA_SHOW_OUT" | grep -qi "ResourceNotFound\|was not found"; then
  echo "✗ Storage account '$TF_BACKEND_SA' 가 RG '$TF_BACKEND_RG' 에 존재하지 않음"
  echo "  → env.sh 의 TF_BACKEND_SA / TF_BACKEND_RG 또는 AZ_SUB 값 확인 필요"
  SA_ACCESS="NOT_FOUND"
elif echo "$SA_SHOW_OUT" | grep -qi "AuthorizationFailed\|does not have authorization\|Forbidden"; then
  echo "✗ Storage account 조회 권한 없음 (Reader 이상 필요)"
  echo "  현재 identity ($ASSIGNEE_DISPLAY) 에 SA 또는 RG/구독 scope 의 Reader 가 없음"
  SA_ACCESS="NO_PERMISSION"
elif echo "$SA_SHOW_OUT" | jq -e '.id' >/dev/null 2>&1; then
  echo "✓ Storage account 조회 성공"
  echo "$SA_SHOW_OUT" | jq '{id, kind, location, allowSharedKeyAccess, allowBlobPublicAccess}'
  SA_ACCESS="OK"
else
  echo "✗ 조회 실패 (원인 분류 불가). 원본 응답:"
  echo "$SA_SHOW_OUT" | head -5
  SA_ACCESS="ERROR"
fi

# ──────────────────────────────────────────────────────────────────────────
# [3] Storage subscription 의 tenant (issuer 비교용)
# ──────────────────────────────────────────────────────────────────────────
title 3/6 "Storage subscription 의 tenant"
STORAGE_TENANT=$(az account list \
  --query "[?id=='$AZ_SUB'].tenantId" -o tsv 2>/dev/null || true)
if [[ -n "$STORAGE_TENANT" ]]; then
  echo "storage subscription tenant = $STORAGE_TENANT"
else
  echo "WARN: 'az account list' 에 구독 미노출 (Lighthouse 위임 가능성)"
fi

# ──────────────────────────────────────────────────────────────────────────
# [4] Data-plane 토큰 decode
# ──────────────────────────────────────────────────────────────────────────
title 4/6 "Storage data-plane 토큰 decode"
TOKEN=$(az account get-access-token \
  --resource https://storage.azure.com/ \
  --query accessToken -o tsv 2>/dev/null || true)
TOKEN_TID=""
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: storage scope 토큰 발급 실패"
else
  PAYLOAD="${TOKEN#*.}"; PAYLOAD="${PAYLOAD%.*}"
  PAYLOAD="${PAYLOAD//-/+}"; PAYLOAD="${PAYLOAD//_//}"
  case $((${#PAYLOAD} % 4)) in
    2) PAYLOAD="${PAYLOAD}==" ;;
    3) PAYLOAD="${PAYLOAD}=" ;;
  esac
  DECODED=$(echo "$PAYLOAD" | base64 -d 2>/dev/null || true)
  if [[ -n "$DECODED" ]]; then
    echo "$DECODED" | jq '{iss, tid, aud, appid, oid, upn}' 2>/dev/null || echo "$DECODED"
    TOKEN_TID=$(echo "$DECODED" | jq -r '.tid // empty' 2>/dev/null)
  fi
fi

# ──────────────────────────────────────────────────────────────────────────
# [5] 현재 신원의 RBAC 권한 분석 (SA scope, 상속 포함)
# ──────────────────────────────────────────────────────────────────────────
title 5/6 "RBAC 권한 분석 — '$ASSIGNEE_DISPLAY' 이 storage 에 갖는 권한"

RA_OUT=$(az role assignment list \
  --assignee "$ASSIGNEE_OID" \
  --scope "$SA_SCOPE" \
  --include-inherited \
  -o json 2>&1 || true)

RBAC_QUERY_OK="false"
DIRECT_ROLES=""    # SA scope 에 직접 부여
RG_ROLES=""        # RG 상속
SUB_ROLES=""       # 구독 상속
MG_ROLES=""        # Management Group 상속

if echo "$RA_OUT" | grep -qi "HTTPSConnectionPool\|Max retries"; then
  echo "✗ 네트워크 오류 (graph.microsoft.com 또는 management.azure.com 도달 실패)"
  echo "  → 사내 방화벽/프록시 확인 또는 'curl -m5 https://management.azure.com' 으로 도달성 확인"
elif echo "$RA_OUT" | grep -qi "AuthorizationFailed"; then
  echo "✗ RBAC 조회 권한 자체가 없음 (보통 Reader 라도 있으면 자기 권한 조회는 가능)"
elif echo "$RA_OUT" | jq -e 'type=="array"' >/dev/null 2>&1; then
  RBAC_QUERY_OK="true"
  COUNT=$(echo "$RA_OUT" | jq 'length')
  echo "총 role assignment 수 (상속 포함): $COUNT"
  echo ""

  if [[ "$COUNT" -gt 0 ]]; then
    echo "$RA_OUT" | jq -r --arg sa "$SA_SCOPE" --arg rg "$RG_SCOPE" --arg sub "$SUB_SCOPE" '
      .[] |
      if   .scope == $sa  then "[SA  direct ] \(.roleDefinitionName)"
      elif .scope == $rg  then "[RG  상속    ] \(.roleDefinitionName)"
      elif .scope == $sub then "[SUB 상속    ] \(.roleDefinitionName)"
      elif (.scope | startswith("/providers/Microsoft.Management")) then
                              "[MG  상속    ] \(.roleDefinitionName)  ← \(.scope)"
      else                    "[기타        ] \(.roleDefinitionName)  ← \(.scope)"
      end
    '

    DIRECT_ROLES=$(echo "$RA_OUT" | jq -r --arg sa "$SA_SCOPE" '[.[] | select(.scope==$sa) | .roleDefinitionName] | join(",")')
    RG_ROLES=$(echo     "$RA_OUT" | jq -r --arg rg "$RG_SCOPE" '[.[] | select(.scope==$rg) | .roleDefinitionName] | join(",")')
    SUB_ROLES=$(echo    "$RA_OUT" | jq -r --arg sub "$SUB_SCOPE" '[.[] | select(.scope==$sub) | .roleDefinitionName] | join(",")')
  else
    echo "  (이 신원에 storage 관련 권한이 SA / RG / 구독 어디에도 없음)"
  fi
else
  echo "✗ 조회 실패 — 원본 응답 (앞 5줄):"
  echo "$RA_OUT" | head -5
fi

# ──────────────────────────────────────────────────────────────────────────
# [6] 부족 권한 판정 + 부여 명령 생성
# ──────────────────────────────────────────────────────────────────────────
title 6/6 "부족 권한 판정 + 부여 명령"

# 어떤 role 이 있으면 어떤 작업이 가능한지
ALL_ROLES="${DIRECT_ROLES},${RG_ROLES},${SUB_ROLES},${MG_ROLES}"
has_role() { echo "$ALL_ROLES" | tr ',' '\n' | grep -qxF "$1"; }

CAN_READ_SA="false"        # az storage account show
CAN_LIST_KEYS="false"      # az storage account keys list (= state backend 가능)
CAN_DATA_PLANE_AAD="false" # --auth-mode login

if has_role "Owner" || has_role "Contributor" || has_role "Reader" || has_role "Storage Account Contributor"; then
  CAN_READ_SA="true"
fi
if has_role "Owner" || has_role "Contributor" || has_role "Storage Account Contributor"; then
  CAN_LIST_KEYS="true"
fi
if has_role "Storage Blob Data Contributor" || has_role "Storage Blob Data Owner" || has_role "Owner"; then
  CAN_DATA_PLANE_AAD="true"
fi

cat <<EOF
현재 신원이 가능한 작업:
  [$([ "$CAN_READ_SA"        = "true" ] && echo ✓ || echo ✗)] az storage account show               (필요: Reader 이상)
  [$([ "$CAN_LIST_KEYS"      = "true" ] && echo ✓ || echo ✗)] az storage account keys list          (필요: Storage Account Contributor 이상)
  [$([ "$CAN_LIST_KEYS"      = "true" ] && echo ✓ || echo ✗)] Terraform backend (state 읽기/쓰기)    (위 keys list 와 동일 권한)
  [$([ "$CAN_DATA_PLANE_AAD" = "true" ] && echo ✓ || echo ✗)] az --auth-mode login (data-plane AAD)  (필요: Storage Blob Data Contributor)
EOF

# 부족 권한과 부여 명령
NEED_GRANTS=()
[[ "$CAN_READ_SA"    = "false" ]] && NEED_GRANTS+=("Reader")
[[ "$CAN_LIST_KEYS"  = "false" ]] && NEED_GRANTS+=("Storage Account Contributor")
# data-plane AAD 는 ARM_ACCESS_KEY 워크어라운드로 회피 가능하므로 필수 아님

if [[ ${#NEED_GRANTS[@]} -eq 0 ]]; then
  echo ""
  echo "✓ state backend 동작에 필요한 최소 권한 충족"
  if [[ "$CAN_DATA_PLANE_AAD" = "false" ]]; then
    echo "  ※ --auth-mode login (data-plane AAD) 만 미보유. account-key 모드 사용 시 문제 없음."
  fi
  if [[ -n "$TOKEN_TID" && -n "$STORAGE_TENANT" && "$TOKEN_TID" != "$STORAGE_TENANT" ]]; then
    echo "  ※ cross-tenant 시나리오 (token tid=$TOKEN_TID vs storage tenant=$STORAGE_TENANT)"
    echo "    → README 4-A 의 ARM_ACCESS_KEY 패턴을 그대로 사용하면 됨"
  fi
  echo ""
  echo "Verdict: PERMISSIONS_OK"
  exit 0
fi

echo ""
echo "부족 권한:"
for r in "${NEED_GRANTS[@]}"; do echo "  - $r"; done

echo ""
echo "──────────────────────────────────────────────────────────────────────"
echo " 관리자(Owner / User Access Administrator)가 실행할 부여 명령"
echo "──────────────────────────────────────────────────────────────────────"

cat <<EOF
# 대상 식별자 (이 메일/메시지에 그대로 전달 가능)
ASSIGNEE_OBJECT_ID="$ASSIGNEE_OID"
ASSIGNEE_DISPLAY="$ASSIGNEE_DISPLAY"
SUB_ID="$AZ_SUB"
SA_SCOPE="$SA_SCOPE"

EOF

# Reader 부족하면 Storage Account Contributor 만 부여해도 SA show + keys list 모두 가능
# (Storage Account Contributor 가 *Microsoft.Storage/storageAccounts/read* 를 포함)
# 따라서 두 권한이 모두 부족하면 Storage Account Contributor 한 줄만 출력
if [[ "$CAN_LIST_KEYS" = "false" ]]; then
cat <<EOF
# (1) Storage Account Contributor — SA 조회 + access key 발급 (state backend 동작에 필수)
az role assignment create \\
  --assignee-object-id "$ASSIGNEE_OID" \\
  --assignee-principal-type ${ASSIGNEE_TYPE} \\
  --role "Storage Account Contributor" \\
  --scope "$SA_SCOPE"

EOF
elif [[ "$CAN_READ_SA" = "false" ]]; then
cat <<EOF
# (1) Reader — SA 메타데이터 조회
az role assignment create \\
  --assignee-object-id "$ASSIGNEE_OID" \\
  --assignee-principal-type ${ASSIGNEE_TYPE} \\
  --role "Reader" \\
  --scope "$SA_SCOPE"

EOF
fi

if [[ "$CAN_DATA_PLANE_AAD" = "false" ]]; then
cat <<EOF
# (2) [선택] Storage Blob Data Contributor — --auth-mode login / use_azuread_auth=true 사용 시
#     account-key 모드(README 4-A)로 우회할 거면 생략 가능
az role assignment create \\
  --assignee-object-id "$ASSIGNEE_OID" \\
  --assignee-principal-type ${ASSIGNEE_TYPE} \\
  --role "Storage Blob Data Contributor" \\
  --scope "$SA_SCOPE"

EOF
fi

# 부여 후 확인 명령
cat <<EOF
# 부여 후 SP 본인이 확인
az role assignment list \\
  --assignee "$ASSIGNEE_OID" \\
  --scope "$SA_SCOPE" \\
  --include-inherited \\
  -o table
EOF

hr
echo "Verdict: PERMISSIONS_MISSING (${#NEED_GRANTS[@]} role(s) needed)"
