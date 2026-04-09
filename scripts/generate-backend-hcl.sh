#!/usr/bin/env bash
#-----------------------------------------------------------------------------
# Bootstrap의 terraform.tfvars에서 Backend 값을 읽어 각 스택 디렉터리에
# backend.hcl 파일을 생성합니다.
# - Bash 전제 (GitHub Actions, GitLab Runner 등 CI에서 bash로 실행)
# - 로컬: 프로젝트 루트에서 ./scripts/generate-backend-hcl.sh
# - CI: REPO_ROOT(또는 GITHUB_WORKSPACE/CI_PROJECT_DIR) 기준으로 실행 가능
# (Bootstrap 적용 후 실행. bootstrap/backend/terraform.tfvars 가 있어야 함.)
# - 피드백1: 01~06 은 **리프 경로**마다 state 1개 (apply는 리프에서만)
#-----------------------------------------------------------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${GITHUB_WORKSPACE:-${CI_PROJECT_DIR:-$REPO_ROOT}}"
BOOTSTRAP_TFVARS="$REPO_ROOT/bootstrap/backend/terraform.tfvars"

if [[ ! -f "$BOOTSTRAP_TFVARS" ]]; then
  echo "ERROR: $BOOTSTRAP_TFVARS 가 없습니다. Bootstrap을 먼저 적용하고 terraform.tfvars를 준비하세요." >&2
  exit 1
fi

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

# 01~06 인프라 리프 (배포 순서)
INFRA_LEAVES=(
  "01.network/resource-group/hub-rg"
  "01.network/security-group/application-security-group/keyvault-clients"
  "01.network/security-group/application-security-group/vm-allowed-clients"
  "01.network/security-group/network-security-group/keyvault-standalone"
  "01.network/security-group/network-security-group/hub-monitoring-vm"
  "01.network/security-group/network-security-group/hub-pep"
  "01.network/security-group/network-security-group/spoke-pep"
  "01.network/vnet/hub-vnet"
  "01.network/subnet/hub-gateway-subnet"
  "01.network/subnet/hub-dnsresolver-inbound-subnet"
  "01.network/subnet/hub-azurefirewall-subnet"
  "01.network/subnet/hub-azurefirewall-management-subnet"
  "01.network/subnet/hub-appgateway-subnet"
  "01.network/subnet/hub-monitoring-vm-subnet"
  "01.network/security-group/security-policy/hub-sg-policy-default"
  "01.network/subnet/hub-pep-subnet"
  "01.network/resource-group/spoke-rg"
  "01.network/vnet/spoke-vnet"
  "01.network/subnet/spoke-apim-subnet"
  "01.network/subnet/spoke-pep-subnet"
  "01.network/security-group/security-policy/spoke-sg-policy-default"
  "01.network/security-group/network-security-rule/hub-monitoring-vm-allow-keyvault-outbound"
  "01.network/security-group/network-security-rule/hub-pep-allow-keyvault-outbound"
  "01.network/security-group/network-security-rule/hub-pep-allow-keyvault-clients-443"
  "01.network/security-group/network-security-rule/hub-monitoring-vm-allow-vm-clients-22"
  "01.network/security-group/network-security-rule/hub-monitoring-vm-allow-vm-clients-3389"
  "01.network/security-group/subnet-network-security-group-association/hub-monitoring-vm-subnet"
  "01.network/security-group/subnet-network-security-group-association/hub-pep-subnet"
  "01.network/security-group/subnet-network-security-group-association/spoke-pep-subnet"
  "01.network/public-ip/hub-vpn-gateway"
  "01.network/virtual-network-gateway/hub-vpn-gateway"
  "01.network/dns/dns-private-resolver/hub"
  "01.network/dns/dns-private-resolver-inbound-endpoint/hub"
  "01.network/dns/private-dns-zone/hub-blob"
  "01.network/dns/private-dns-zone/hub-vault"
  "01.network/dns/private-dns-zone/spoke-azure-api"
  "01.network/dns/private-dns-zone/spoke-openai"
  "01.network/dns/private-dns-zone/spoke-cognitiveservices"
  "01.network/dns/private-dns-zone/spoke-ml"
  "01.network/dns/private-dns-zone/spoke-notebooks"
  "01.network/dns/private-dns-zone-vnet-link/hub-blob-to-hub-vnet"
  "01.network/dns/private-dns-zone-vnet-link/hub-vault-to-hub-vnet"
  "01.network/dns/private-dns-zone-vnet-link/hub-openai-to-hub-vnet"
  "01.network/dns/private-dns-zone-vnet-link/spoke-azure-api-to-spoke-vnet"
  "01.network/dns/private-dns-zone-vnet-link/spoke-openai-to-spoke-vnet"
  "01.network/dns/private-dns-zone-vnet-link/spoke-cognitiveservices-to-spoke-vnet"
  "01.network/dns/private-dns-zone-vnet-link/spoke-ml-to-spoke-vnet"
  "01.network/dns/private-dns-zone-vnet-link/spoke-notebooks-to-spoke-vnet"
  "01.network/route/hub-route-default"
  "01.network/route/spoke-route-default"
  "02.storage/monitoring"
  "03.shared-services/log-analytics"
  "03.shared-services/shared"
  "04.apim/workload"
  "05.ai-services/workload"
)

# 06 compute — VM별 리프
COMPUTE_SUBDIRS=(linux-monitoring-vm windows-example)

# 07.identity / 08.rbac 리프
RBAC_IDENTITY_LEAVES=(
  "07.identity/group-membership/admin-core"
  "07.identity/group-membership/ai-developer-core"
  "08.rbac/group/admin-hub-scope"
  "08.rbac/group/ai-developer-spoke-scope"
  "08.rbac/principal/hub-assignments"
  "08.rbac/principal/spoke-assignments"
  "08.rbac/authorization/hub-assignments"
  "08.rbac/authorization/spoke-assignments"
)

# 09.connectivity 리프
CONNECTIVITY_LEAVES=(
  "09.connectivity/peering/hub-to-spoke"
  "09.connectivity/peering/spoke-to-hub"
  "09.connectivity/diagnostics/hub"
)

DEV_DIR="$REPO_ROOT/azure/dev"

write_backend_hcl() {
  local dir="$1"
  local key="$2"
  local hcl="$dir/backend.hcl"
  if [[ ! -d "$dir" ]]; then
    echo "SKIP (디렉터리 없음): $dir"
    return
  fi
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
}

for leaf in "${INFRA_LEAVES[@]}"; do
  key="azure/dev/${leaf}/terraform.tfstate"
  write_backend_hcl "$DEV_DIR/$leaf" "$key"
done

for leaf in "${RBAC_IDENTITY_LEAVES[@]}"; do
  key="azure/dev/${leaf}/terraform.tfstate"
  write_backend_hcl "$DEV_DIR/$leaf" "$key"
done

for leaf in "${CONNECTIVITY_LEAVES[@]}"; do
  key="azure/dev/${leaf}/terraform.tfstate"
  write_backend_hcl "$DEV_DIR/$leaf" "$key"
done

for sub in "${COMPUTE_SUBDIRS[@]}"; do
  key="azure/dev/06.compute/$sub/terraform.tfstate"
  write_backend_hcl "$DEV_DIR/06.compute/$sub" "$key"
done

echo "Done. 각 스택·리프 디렉터리에서 terraform init -backend-config=backend.hcl 후 plan/apply 하세요."
