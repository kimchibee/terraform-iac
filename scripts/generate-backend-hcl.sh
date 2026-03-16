#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# Bootstrap의 terraform.tfvars에서 Backend 값을 읽어 각 스택 디렉터리에
# backend.hcl 파일을 생성합니다.
# - Bash 전제 (GitHub Actions, GitLab Runner 등 CI에서 bash로 실행)
# - 로컬: 프로젝트 루트에서 ./scripts/generate-backend-hcl.sh
# - CI: REPO_ROOT(또는 GITHUB_WORKSPACE/CI_PROJECT_DIR) 기준으로 실행 가능
# (Bootstrap 적용 후 실행. bootstrap/backend/terraform.tfvars 가 있어야 함.)
# - 스택 디렉터리: azure/dev/01.network, 02.storage, ... (배포 순서 접두사)
#-----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# GitHub Actions(GITHUB_WORKSPACE) / GitLab Runner(CI_PROJECT_DIR) 사용 시 해당 경로로 사용
REPO_ROOT="${GITHUB_WORKSPACE:-${CI_PROJECT_DIR:-$REPO_ROOT}}"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"

if [[ ! -f "$BOOTSTRAP_TFVARS" ]]; then
  echo "ERROR: $BOOTSTRAP_TFVARS 가 없습니다. Bootstrap을 먼저 적용하고 terraform.tfvars를 준비하세요." >&2
  exit 1
fi

# HCL key = "value" 형태에서 value만 추출 (macOS/BSD sed 호환: [[:space:]] 사용)
get_var() {
  grep -E "^[[:space:]]*${1}[[:space:]]*=" "$BOOTSTRAP_TFVARS" | sed -nE 's/.*=[[:space:]]*"([^"]+)".*/\1/p' | tr -d ' \r'
}

resource_group_name=$(get_var "resource_group_name")
storage_account_name=$(get_var "storage_account_name")
container_name=$(get_var "container_name")

if [[ -z "$resource_group_name" || -z "$storage_account_name" || -z "$container_name" ]]; then
  echo "ERROR: terraform.tfvars에서 resource_group_name, storage_account_name, container_name 을 읽지 못했습니다." >&2
  exit 1
fi

# 배포 순서대로 디렉터리명 (접두사 01. ~ 08.)
STACKS=(01.network 02.storage 03.shared-services 04.apim 05.ai-services 06.compute 07.rbac 08.connectivity)
# compute 하위는 모듈로만 사용. backend는 compute 루트 1개
COMPUTE_SUBDIRS=(linux-monitoring-vm windows-example)
DEV_DIR="$REPO_ROOT/azure/dev"

for stack in "${STACKS[@]}"; do
  case "$stack" in
    01.network)         key="azure/dev/01.network/terraform.tfstate" ;;
    02.storage)         key="azure/dev/02.storage/terraform.tfstate" ;;
    03.shared-services) key="azure/dev/03.shared-services/terraform.tfstate" ;;
    04.apim)            key="azure/dev/04.apim/terraform.tfstate" ;;
    05.ai-services)     key="azure/dev/05.ai-services/terraform.tfstate" ;;
    06.compute)         key="azure/dev/06.compute/terraform.tfstate" ;;
    07.rbac)            key="azure/dev/07.rbac/terraform.tfstate" ;;
    08.connectivity)    key="azure/dev/08.connectivity/terraform.tfstate" ;;
    *)                  echo "SKIP unknown stack: $stack" ; continue ;;
  esac

  dir="$DEV_DIR/$stack"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP (디렉터리 없음): $dir"
    continue
  fi

  hcl="$dir/backend.hcl"
  if [[ -f "$hcl" ]]; then
    echo "OVERWRITE $hcl"
  fi

  cat > "$hcl" <<EOF
resource_group_name  = "$resource_group_name"
storage_account_name = "$storage_account_name"
container_name       = "$container_name"
key                  = "$key"
EOF
  echo "CREATED $hcl"
done

# compute 하위 디렉터리별 backend.hcl (디렉터리 단위 VM 관리)
for sub in "${COMPUTE_SUBDIRS[@]}"; do
  dir="$DEV_DIR/06.compute/$sub"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP (디렉터리 없음): $dir"
    continue
  fi
  key="azure/dev/06.compute/$sub/terraform.tfstate"
  hcl="$dir/backend.hcl"
  if [[ -f "$hcl" ]]; then
    echo "OVERWRITE $hcl"
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
