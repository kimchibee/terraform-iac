# Spoke VNet 리프
# ?�일 책임: Spoke Virtual Network ?�체�??�성
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
}

module "spoke_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  tags                = var.tags
  resource_group_name = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
  vnet_name           = local.spoke_vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = {}
}
