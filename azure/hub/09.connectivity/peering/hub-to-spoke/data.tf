# Hub → Spoke VNet Peering (Hub 구독에서 생성)
data "terraform_remote_state" "network_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "azurerm_virtual_network" "local" {
  provider            = azurerm.hub
  name                = data.terraform_remote_state.network_hub.outputs.hub_vnet_name
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}
