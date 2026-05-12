module "dns_private_resolver" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-dnsresolver?ref=main"

  name                        = "${var.project_name}-x-x-pdr"
  resource_group_name         = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location                    = var.location
  virtual_network_resource_id = data.terraform_remote_state.hub_vnet.outputs.hub_vnet_id
  tags                        = var.tags
  enable_telemetry            = false
  inbound_endpoints = {
    hub = {
      name        = "hub-dns-inbound"
      subnet_name = data.terraform_remote_state.hub_dns_inbound_subnet.outputs.hub_subnet_name
    }
  }
}
