#!/usr/bin/env bash
#--------------------------------------------------------------
# Terraform Wrapper Script
# terraform.tfvars에서 backend 설정을 읽어 자동으로 전달
#
# 사용법:
#   ../scripts/tf.sh init     # backend.hcl 자동 생성 + terraform init
#   ../scripts/tf.sh plan     # terraform plan
#   ../scripts/tf.sh apply    # terraform apply
#   ../scripts/tf.sh destroy  # terraform destroy
#--------------------------------------------------------------
set -euo pipefail

COMMAND="${1:-help}"
shift || true

# 현재 디렉토리에서 terraform.tfvars 읽기
TFVARS_FILE="terraform.tfvars"
if [ ! -f "${TFVARS_FILE}" ]; then
  echo "ERROR: ${TFVARS_FILE} not found in $(pwd)"
  exit 1
fi

# terraform.tfvars에서 backend 관련 값 추출
extract_var() {
  grep "^${1}" "${TFVARS_FILE}" 2>/dev/null | sed 's/.*= *"\(.*\)"/\1/' | tr -d ' '
}

BACKEND_RG=$(extract_var "backend_resource_group_name")
BACKEND_SA=$(extract_var "backend_storage_account_name")
BACKEND_CONTAINER=$(extract_var "backend_container_name")

# key는 현재 디렉토리의 상대 경로로 자동 생성
# azure-3/01.network/vnet/hub-vnet → 01.network/vnet/hub-vnet/terraform.tfstate
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AZURE3_ROOT="$(dirname "${SCRIPT_DIR}")"
LEAF_REL=$(python3 -c "import os; print(os.path.relpath('$(pwd)', '${AZURE3_ROOT}'))")
BACKEND_KEY="${LEAF_REL}/terraform.tfstate"

case "${COMMAND}" in
  init)
    # backend.hcl 생성
    cat > backend.hcl <<HCL
resource_group_name  = "${BACKEND_RG}"
storage_account_name = "${BACKEND_SA}"
container_name       = "${BACKEND_CONTAINER}"
key                  = "${BACKEND_KEY}"
HCL
    echo "Generated backend.hcl (key=${BACKEND_KEY})"
    terraform init -backend-config=backend.hcl -input=false "$@"
    ;;
  plan)
    terraform plan -input=false "$@"
    ;;
  apply)
    terraform apply "$@"
    ;;
  destroy)
    terraform destroy "$@"
    ;;
  *)
    echo "Usage: tf.sh {init|plan|apply|destroy} [terraform args...]"
    exit 1
    ;;
esac
