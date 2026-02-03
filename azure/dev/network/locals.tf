#--------------------------------------------------------------
# Network Stack Local Values
#--------------------------------------------------------------

locals {
  # 공통 네이밍 prefix
  name_prefix = "${var.project_name}-x-x"

  # Hub 리소스 이름
  hub_resource_group_name      = "${local.name_prefix}-rg"
  hub_vnet_name                = "${local.name_prefix}-vnet"
  hub_vpn_gateway_name         = "${local.name_prefix}-vpng"
  hub_dns_resolver_name        = "${local.name_prefix}-pdr"

  # Spoke 리소스 이름 (VNet만 network 스택에서 관리)
  spoke_resource_group_name = "${local.name_prefix}-spoke-rg"
  spoke_vnet_name           = "${local.name_prefix}-spoke-vnet"
  # APIM, OpenAI, AI Foundry는 각각의 스택에서 관리
}
