#--------------------------------------------------------------
# Spoke VNet 모듈 (network 루트에서 호출)
#--------------------------------------------------------------
module "spoke_vnet" {
  source = "./terraform_modules/spoke-vnet"

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  resource_group_name = var.resource_group_name
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets

  enable_hub_peering     = false
  hub_vnet_id            = var.hub_vnet_id
  hub_resource_group_name = var.hub_resource_group_name
  enable_private_dns_links = true
  private_dns_zone_ids      = var.private_dns_zone_ids
  spoke_private_dns_zones  = var.spoke_private_dns_zones
  enable_pep_nsg           = true
  pep_subnet_name          = "pep-snet"
}
