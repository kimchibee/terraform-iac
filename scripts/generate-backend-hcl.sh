#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# Bootstrap의 terraform.tfvars에서 Backend 값을 읽어 각 스택 디렉터리에
# backend.hcl 파일을 생성합니다.
# 사용법: 프로젝트 루트에서 ./scripts/generate-backend-hcl.sh
# (Bootstrap 적용 후 실행. bootstrap/backend/terraform.tfvars 가 있어야 함.)
#-----------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"

if [[ ! -f "$BOOTSTRAP_TFVARS" ]]; then
  echo "ERROR: $BOOTSTRAP_TFVARS 가 없습니다. Bootstrap을 먼저 적용하고 terraform.tfvars를 준비하세요." >&2
  exit 1
fi

# HCL key = "value" 형태에서 value 추출 (앞뒤 공백 제거)
get_var() {
  grep -E "^\s*${1}\s*=" "$BOOTSTRAP_TFVARS" | sed -E 's/.*=\s*"([^"]+)".*/\1/' | tr -d ' \r'
}

resource_group_name=$(get_var "resource_group_name")
storage_account_name=$(get_var "storage_account_name")
container_name=$(get_var "container_name")

if [[ -z "$resource_group_name" || -z "$storage_account_name" || -z "$container_name" ]]; then
  echo "ERROR: terraform.tfvars에서 resource_group_name, storage_account_name, container_name 을 읽지 못했습니다." >&2
  exit 1
fi

STACKS=(network storage shared-services apim ai-services compute connectivity)
DEV_DIR="$REPO_ROOT/azure/dev"

for stack in "${STACKS[@]}"; do
  case "$stack" in
    network)         key="azure/dev/network/terraform.tfstate" ;;
    storage)         key="azure/dev/storage/terraform.tfstate" ;;
    shared-services) key="azure/dev/shared-services/terraform.tfstate" ;;
    apim)            key="azure/dev/apim/terraform.tfstate" ;;
    ai-services)     key="azure/dev/ai-services/terraform.tfstate" ;;
    compute)         key="azure/dev/compute/terraform.tfstate" ;;
    connectivity)    key="azure/dev/connectivity/terraform.tfstate" ;;
    *)               echo "SKIP unknown stack: $stack" ; continue ;;
  esac

  dir="$DEV_DIR/$stack"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP (디렉터리 없음): $dir"
    continue
  fi

  hcl="$dir/backend.hcl"
  if [[ -f "$hcl" ]]; then
    echo "SKIP (이미 존재): $hcl"
    continue
  fi

  cat > "$hcl" <<EOF
resource_group_name  = "$resource_group_name"
storage_account_name = "$storage_account_name"
container_name       = "$container_name"
key                  = "$key"
EOF
  echo "CREATED $hcl"
done

echo "Done. 각 스택에서 terraform init -backend-config=backend.hcl 후 plan/apply 하세요."
