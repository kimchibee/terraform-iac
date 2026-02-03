#--------------------------------------------------------------
# Network Stack
# Hub VNet과 Spoke VNet을 관리하는 스택
# AWS 방식: 각 스택이 독립적으로 배포 가능
#--------------------------------------------------------------

#--------------------------------------------------------------
# Hub VNet Module
#--------------------------------------------------------------
module "hub_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/hub-vnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group
  resource_group_name = local.hub_resource_group_name

  # Virtual Network
  vnet_name          = local.hub_vnet_name
  vnet_address_space = var.hub_vnet_address_space
  subnets            = var.hub_subnets

  # VPN Gateway
  vpn_gateway_name      = local.hub_vpn_gateway_name
  vpn_gateway_sku       = var.vpn_gateway_sku
  vpn_gateway_type      = var.vpn_gateway_type
  local_gateway_configs = var.local_gateway_configs
  vpn_shared_key        = var.vpn_shared_key

  # DNS Private Resolver
  dns_resolver_name = local.hub_dns_resolver_name

  # Feature Flags
  enable_dns_forwarding_ruleset = var.enable_dns_forwarding_ruleset
}

#--------------------------------------------------------------
# Spoke VNet Module
# Hub VNet 정보는 이 스택 내에서 직접 참조 (같은 State 파일)
# Storage와 Shared Services는 나중에 remote_state로 참조
#--------------------------------------------------------------
module "spoke_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/spoke-vnet?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group
  resource_group_name = local.spoke_resource_group_name

  # Virtual Network
  vnet_name          = local.spoke_vnet_name
  vnet_address_space = var.spoke_vnet_address_space
  subnets            = var.spoke_subnets

  # Hub VNet Peering (같은 스택 내에서 직접 참조)
  enable_hub_peering     = true
  hub_vnet_id            = module.hub_vnet.vnet_id
  hub_resource_group_name = module.hub_vnet.resource_group_name

  # Private DNS Zone Links (from Hub)
  enable_private_dns_links = true
  private_dns_zone_ids     = module.hub_vnet.private_dns_zone_ids

  # NSG for Private Endpoint
  enable_pep_nsg = true
  pep_subnet_name = "pep-snet"

  depends_on = [module.hub_vnet]
}
