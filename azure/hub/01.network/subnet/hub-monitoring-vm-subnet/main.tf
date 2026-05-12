module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.0.1.0/24"]
  service_endpoints_with_location = [
    for service in local.service_endpoints : {
      service   = service
      locations = ["*"]
    }
  ]
  network_security_group = {
    id = data.terraform_remote_state.hub_nsg.outputs.network_security_group_id
  }
}
