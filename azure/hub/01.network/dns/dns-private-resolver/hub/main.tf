module "dns_private_resolver" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-dnsresolver-main.git?ref=main"

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
