module "link" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privatednszone/modules/private_dns_virtual_network_link?ref=main"

  name               = "spoke-openai-to-spoke-vnet"
  parent_id          = data.azurerm_private_dns_zone.zone.id
  virtual_network_id = data.terraform_remote_state.vnet.outputs.spoke_vnet_id
}
