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
