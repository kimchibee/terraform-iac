module "vnet_peering_spoke_to_hub" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/peering?ref=main"

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
