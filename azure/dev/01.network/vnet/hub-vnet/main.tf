#--------------------------------------------------------------
# Hub VNet 리프
# Single responsibility: provision Hub Virtual Network only
# Subnet/DNS/Resolver/VPN/NSG/Rule/Association are managed in separate leaves
#--------------------------------------------------------------

data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}

locals {
  name_prefix   = "${var.project_name}-x-x"
  hub_vnet_name = "${local.name_prefix}-vnet"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "hub_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.7.1?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_vnet_name
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location            = var.location
  address_space       = toset(var.hub_vnet_address_space)
  subnets             = {}
  tags                = local.common_tags
  enable_telemetry    = false
}
