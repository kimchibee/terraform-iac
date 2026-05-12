module "link" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-privatednszone-main.git//modules/private_dns_virtual_network_link?ref=main"

  name               = "spoke-cognitiveservices-to-spoke-vnet"
  parent_id          = data.azurerm_private_dns_zone.zone.id
  virtual_network_id = data.terraform_remote_state.vnet.outputs.spoke_vnet_id
}
