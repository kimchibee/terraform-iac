#!/usr/bin/env bash
# 공통 환경변수 — 작업 시작 시 `source scripts/import/env.sh` 로 로드
#
# Service Principal 인증을 쓰려면 source 전에 미리 export 해 둘 것:
#   ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID
#   ARM_SUBSCRIPTION_ID (또는 HUB_SUBSCRIPTION_ID / SPOKE_SUBSCRIPTION_ID)
# 위 변수가 셋되어 있으면 그 값을 우선 사용. 없으면 아래 하드코드 fallback.

# 대상 구독 — ARM_SUBSCRIPTION_ID > HUB_SUBSCRIPTION_ID > 하드코드
export AZ_SUB="${ARM_SUBSCRIPTION_ID:-${HUB_SUBSCRIPTION_ID:-20e3a0f3-f1af-4cc5-8092-dc9b276a9911}}"

# Terraform backend (state SA)
export TF_BACKEND_RG="terraform-state-rg"
export TF_BACKEND_SA="tfstatea9911"
export TF_BACKEND_CONTAINER="tfstate"

# Terraform 변수 — subscription 단위로 고정인 공통 값
# (terraform 이 TF_VAR_* 환경변수를 자동 인식. tfvars 가 있으면 tfvars 가 우선)
# 다른 프로젝트에서 작업할 땐 source 전에 미리 export 로 override:
#   export TF_VAR_project_name=other-proj
#   source scripts/import/env.sh
export TF_VAR_project_name="${TF_VAR_project_name:-test}"
export TF_VAR_environment="${TF_VAR_environment:-dev}"
export TF_VAR_location="${TF_VAR_location:-Korea Central}"

# subscription_id: HUB_SUBSCRIPTION_ID / SPOKE_SUBSCRIPTION_ID 셋되어 있으면 사용, 없으면 AZ_SUB
export TF_VAR_hub_subscription_id="${HUB_SUBSCRIPTION_ID:-$AZ_SUB}"
export TF_VAR_spoke_subscription_id="${SPOKE_SUBSCRIPTION_ID:-$AZ_SUB}"

# Terraform azurerm provider는 ARM_* 변수를 자동 인식 — 별도 처리 불요.
# az CLI 도 SP 인증으로 동작시키려면 scripts/import/az-sp-login.sh 를 1회 실행할 것.

# TLS 인터셉션 환경 (회사 프록시 등): setup-tls-trust.sh 가 만든 combined-ca.pem
# 이 있으면 자동 export. 없으면 무동작.
_tls_pem="${HOME}/.config/terraform-iac/combined-ca.pem"
if [[ -f "$_tls_pem" ]]; then
  export REQUESTS_CA_BUNDLE="$_tls_pem"   # Python requests (az CLI)
  export SSL_CERT_FILE="$_tls_pem"        # Go (Terraform), Python ssl
  export CURL_CA_BUNDLE="$_tls_pem"       # curl
fi
unset _tls_pem

# 리포 루트 (스크립트에서 사용)
# Resolve script directory in both bash (BASH_SOURCE) and zsh ($0 when sourced)
_env_sh_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export REPO_ROOT="$(cd "$_env_sh_dir/../.." && pwd)"
unset _env_sh_dir
export AZURE_ROOT="$REPO_ROOT/azure"
export IMPORT_DOC_DIR="$REPO_ROOT/docs/import"
