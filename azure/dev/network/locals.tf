#--------------------------------------------------------------
# Network Stack Local Values
# 스택 디렉터리 내에서 네이밍을 관리
#--------------------------------------------------------------

locals {
  # 공통 네이밍 prefix
  name_prefix = "${var.project_name}-x-x"

  # Hub 리소스 이름
  hub_resource_group_name = "${local.name_prefix}-rg"
  hub_vnet_name           = "${local.name_prefix}-vnet"
  hub_vpn_gateway_name    = "${local.name_prefix}-vpng"
  hub_dns_resolver_name   = "${local.name_prefix}-pdr"

  # Spoke 리소스 이름 (VNet만 network 스택에서 관리)
  spoke_resource_group_name = "${local.name_prefix}-spoke-rg"
  spoke_vnet_name           = "${local.name_prefix}-spoke-vnet"
  # APIM, OpenAI, AI Foundry는 각각의 스택에서 관리

  # Hub 서브넷 네이밍 (이 디렉터리 locals에서 관리, 다른 리소스 이름과 동일 방식)
  hub_subnet_names = toset([
    "GatewaySubnet",
    "DNSResolver-Inbound",
    "AzureFirewallSubnet",
    "AzureFirewallManagementSubnet",
    "AppGatewaySubnet",
    "Monitoring-VM-Subnet",
    "pep-snet"
  ])

  # Spoke 서브넷 네이밍
  spoke_subnet_names = toset([
    "apim-snet",
    "pep-snet"
  ])

  # 서브넷 네이밍 규칙 적용: 위에서 정의한 이름만 모듈로 전달
  hub_subnets   = { for k, v in var.hub_subnets : k => v if contains(local.hub_subnet_names, k) }
  spoke_subnets = { for k, v in var.spoke_subnets : k => v if contains(local.spoke_subnet_names, k) }

  # PE용 서브넷 이름 (다른 스택에서 참조 시 동일 이름 사용)
  pep_subnet_name = "pep-snet"
}
