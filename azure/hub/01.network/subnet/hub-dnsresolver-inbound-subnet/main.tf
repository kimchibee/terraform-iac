module "subnet" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.0.0.64/28"]
  delegations = [
    {
      name = "Microsoft.Network.dnsResolvers"
      service_delegation = {
        name = "Microsoft.Network/dnsResolvers"
      }
    }
  ]
}
