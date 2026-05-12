module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.0.2.64/26"]
}
