module "route_table" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-routetable?ref=main"

  location            = var.location
  name                = "${local.name_prefix}-spoke-udr"
  resource_group_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
  tags                = merge(var.tags, { Environment = var.environment })

  bgp_route_propagation_enabled = var.bgp_route_propagation_enabled

  routes_legacy_mode = true
  routes = {
    for k, r in local.routes_map : k => {
      name                   = r.name
      address_prefix         = r.address_prefix
      next_hop_type          = r.next_hop_type
      next_hop_in_ip_address = try(r.next_hop_in_ip_address, null)
    }
  }

  subnet_resource_ids = local.subnet_resource_ids

  enable_telemetry = false
}
