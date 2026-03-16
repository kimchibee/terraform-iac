#--------------------------------------------------------------
# Hub VNet 모듈 (network 루트에서 호출)
#--------------------------------------------------------------
module "hub_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/hub-vnet?ref=main"

  providers = {
    azurerm = azurerm
  }

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  resource_group_name = var.resource_group_name
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets

  vpn_gateway_name      = var.vpn_gateway_name
  vpn_gateway_sku       = var.vpn_gateway_sku
  vpn_gateway_type      = var.vpn_gateway_type
  local_gateway_configs = var.local_gateway_configs
  vpn_shared_key        = var.vpn_shared_key

  dns_resolver_name = var.dns_resolver_name
  enable_dns_forwarding_ruleset = var.enable_dns_forwarding_ruleset
}
