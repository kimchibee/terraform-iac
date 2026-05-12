#!/usr/bin/env bash
# az CLI 를 Service Principal 환경변수로 로그인
# Pre-condition: scripts/import/env.sh 를 먼저 source 했고,
# 다음 변수가 export 되어 있어야 함:
#   ARM_CLIENT_ID
#   ARM_CLIENT_SECRET
#   ARM_TENANT_ID
#   ARM_SUBSCRIPTION_ID (또는 HUB_SUBSCRIPTION_ID — env.sh 에서 AZ_SUB 로 정규화)
set -euo pipefail

: "${ARM_CLIENT_ID:?ARM_CLIENT_ID 가 셋되어 있어야 함}"
: "${ARM_CLIENT_SECRET:?ARM_CLIENT_SECRET 가 셋되어 있어야 함}"
: "${ARM_TENANT_ID:?ARM_TENANT_ID 가 셋되어 있어야 함}"
: "${AZ_SUB:?AZ_SUB 가 셋되어 있어야 함 (env.sh source 필요)}"

# 이미 SP 로 로그인되어 있고 대상 구독이 같으면 skip
CURRENT_SUB="$(az account show --query id -o tsv 2>/dev/null || true)"
if [[ "$CURRENT_SUB" == "$AZ_SUB" ]]; then
  echo "[az-sp-login] already authenticated for subscription $AZ_SUB — skip"
  exit 0
fi

echo "[az-sp-login] service principal 로그인 (tenant=$ARM_TENANT_ID, sub=$AZ_SUB)"
az login \
  --service-principal \
  --username "$ARM_CLIENT_ID" \
  --password "$ARM_CLIENT_SECRET" \
  --tenant "$ARM_TENANT_ID" \
  --output none

az account set --subscription "$AZ_SUB"
az account show --query '{name:name, id:id, tenantId:tenantId}' -o table
