#--------------------------------------------------------------
# Hub VNet 리프
# Single responsibility: provision Hub Virtual Network only
# Subnet/DNS/Resolver/VPN/NSG/Rule/Association are managed in separate leaves
#--------------------------------------------------------------


module "hub_vnet" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_vnet_name
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location            = var.location
  address_space       = toset(var.hub_vnet_address_space)
  subnets             = {}
  tags                = local.common_tags
  enable_telemetry    = false
}
