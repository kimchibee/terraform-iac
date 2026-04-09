#--------------------------------------------------------------
# Spoke apim-snet (`spoke-apim-subnet`)
# Single responsibility: create one apim-snet subnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

locals {
  subnet_name       = "apim-snet"
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.spoke
  name                = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.1.0.0/26"]
  service_endpoints_with_location = [
    for service in local.service_endpoints : {
      service   = service
      locations = ["*"]
    }
  ]
}
