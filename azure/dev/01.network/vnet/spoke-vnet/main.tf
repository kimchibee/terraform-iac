# Spoke VNet 리프
# Single responsibility: provision Spoke Virtual Network only
data "terraform_remote_state" "spoke_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/spoke-rg/terraform.tfstate"
  }
}

locals {
  name_prefix     = "${var.project_name}-x-x"
  spoke_vnet_name = "${local.name_prefix}-${var.vnet_suffix}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "spoke_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.7.1?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                = local.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
  location            = var.location
  address_space       = toset(var.vnet_address_space)
  subnets             = {}
  tags                = local.common_tags
  enable_telemetry    = false
}
