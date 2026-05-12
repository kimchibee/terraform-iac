module "spoke_vnet" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                = local.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
  location            = var.location
  address_space       = toset(var.vnet_address_space)
  subnets             = {}
  tags                = local.common_tags
  enable_telemetry    = false
}
