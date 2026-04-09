# Spoke → Hub VNet Peering (Spoke 구독에서 생성)
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
  provider            = azurerm.spoke
  name                = data.terraform_remote_state.network_spoke.outputs.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_name
}

module "vnet_peering_spoke_to_hub" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/peering?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                         = "${data.terraform_remote_state.network_spoke.outputs.spoke_vnet_name}-to-hub"
  parent_id                    = data.azurerm_virtual_network.local.id
  remote_virtual_network_id    = data.terraform_remote_state.network_hub.outputs.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
