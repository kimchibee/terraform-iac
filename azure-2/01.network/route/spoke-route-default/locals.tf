locals {
  name_prefix         = "${var.project_name}-x-x"
  monitoring_prefixes = try(data.terraform_remote_state.hub_monitoring_subnet.outputs.hub_subnet_address_prefixes, [])
  hub_monitoring_cidr = length(local.monitoring_prefixes) > 0 ? local.monitoring_prefixes[0] : var.hub_monitoring_subnet_cidr_fallback

  auto_routes_to_monitoring = var.enable_route_to_hub_monitoring ? [
    {
      name                   = "to-hub-monitoring-vm"
      address_prefix         = local.hub_monitoring_cidr
      next_hop_type          = var.hub_monitoring_route_next_hop_type
      next_hop_in_ip_address = var.hub_monitoring_route_next_hop_ip
    }
  ] : []

  all_routes = concat(var.custom_routes, local.auto_routes_to_monitoring)
  routes_map = { for r in local.all_routes : r.name => r }

  spoke_subnet_ids_by_key = {
    "apim-snet" = data.terraform_remote_state.spoke_apim_subnet.outputs.spoke_subnet_id
    "pep-snet"  = data.terraform_remote_state.spoke_pep_subnet.outputs.spoke_subnet_id
  }

  subnet_resource_ids = {
    for k in var.spoke_subnet_keys_for_route_table : k => local.spoke_subnet_ids_by_key[k]
  }
}
