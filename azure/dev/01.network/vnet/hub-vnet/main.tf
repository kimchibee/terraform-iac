#--------------------------------------------------------------
# Hub VNet 리프
# ?�일 책임: Hub Virtual Network ?�체�??�성
# Subnet / DNS / Resolver / VPN / NSG / Rule / Association ?� 별도 리프?�서 관�?
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
}

module "hub_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.hub
  }

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  tags                = var.tags
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  vnet_name           = local.hub_vnet_name
  vnet_address_space  = var.hub_vnet_address_space
  subnets             = {}
}
