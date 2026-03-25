# Hub UDR leaf: creates route table, optionally associates Monitoring-VM-Subnet,
# and manages custom/auto routes for Spoke traffic.
# Route table is provisioned via shared AVM wrapper module.
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_security_policy" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/security-policy/hub-sg-policy-default/terraform.tfstate"
  }
}

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

module "route_table" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/route-table?ref=chore/avm-wave1-modules-prune-and-convert"

  location            = var.location
  name                = "${local.name_prefix}-hub-udr"
  resource_group_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
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
