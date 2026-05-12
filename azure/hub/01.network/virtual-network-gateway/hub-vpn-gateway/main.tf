module "virtual_network_gateway" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-ptn-vnetgateway-main.git?ref=main"

  parent_id = data.azurerm_resource_group.parent.id
  name      = "${var.project_name}-x-x-vpng"
  location  = var.location
  tags      = var.tags

  virtual_network_id                = local.virtual_network_id
  virtual_network_gateway_subnet_id = local.gateway_subnet_id

  vpn_type                  = "RouteBased"
  vpn_generation            = "Generation1"
  vpn_active_active_enabled = false
  vpn_bgp_enabled           = false

  enable_telemetry = false
}
