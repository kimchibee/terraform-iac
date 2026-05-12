locals {
  name_prefix        = "${var.project_name}-x-x"
  spoke_prefix_first = try(data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_address_space[0], var.spoke_vnet_cidr_fallback)
  firewall_private_ip = try(data.terraform_remote_state.hub_security_policy.outputs.hub_firewall_private_ip, null)
  spoke_route_next_hop_ip_effective = (
    var.spoke_route_next_hop_type == "VirtualAppliance"
    ? (var.spoke_route_next_hop_ip != null ? var.spoke_route_next_hop_ip : local.firewall_private_ip)
    : null
  )

  auto_routes_to_spoke = var.enable_route_to_spoke_vnet && (
    var.spoke_route_next_hop_type != "VirtualAppliance" || local.spoke_route_next_hop_ip_effective != null
  ) ? [
    {
      name                   = "to-spoke-workloads"
      address_prefix         = local.spoke_prefix_first
      next_hop_type          = var.spoke_route_next_hop_type
      next_hop_in_ip_address = local.spoke_route_next_hop_ip_effective
    }
  ] : []

  all_routes = concat(var.custom_routes, local.auto_routes_to_spoke)
  routes_map = { for r in local.all_routes : r.name => r }

  monitoring_subnet_id = try(data.terraform_remote_state.hub_monitoring_subnet.outputs.hub_subnet_id, null)
  subnet_resource_ids = (var.associate_route_table_to_monitoring_subnet && local.monitoring_subnet_id != null) ? {
    monitoring_vm = local.monitoring_subnet_id
  } : {}
}
