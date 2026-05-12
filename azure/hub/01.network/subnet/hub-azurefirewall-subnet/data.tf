#--------------------------------------------------------------
# Hub AzureFirewallSubnet (`hub-azurefirewall-subnet`)
# Single responsibility: create one AzureFirewallSubnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.hub
  name                = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}
