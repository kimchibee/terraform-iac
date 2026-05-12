module "subnet" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                              = local.subnet_name
  parent_id                         = data.azurerm_virtual_network.parent.id
  address_prefixes                  = ["10.1.0.64/26"]
  private_endpoint_network_policies = "Disabled"
  network_security_group = {
    id = data.terraform_remote_state.spoke_nsg.outputs.network_security_group_id
  }
}
