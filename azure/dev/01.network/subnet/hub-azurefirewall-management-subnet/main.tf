#--------------------------------------------------------------
# Hub AzureFirewallManagementSubnet (`hub-azurefirewall-management-subnet`)
# Single responsibility: create one AzureFirewallManagementSubnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

locals {
  subnet_name = "AzureFirewallManagementSubnet"
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.hub
  name                = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.0.2.64/26"]
}
