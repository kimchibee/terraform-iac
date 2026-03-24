# Hub UDR ??Monitoring-VM-Subnet ???�택)??Route Table???�결?�고, Spoke ?�??��로의 ?�용???�의 경로�??????�음.
# Route Table: 공동 모듈 route-table ??AVM avm-res-network-routetable
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

locals {
  name_prefix        = "${var.project_name}-x-x"
  spoke_prefix_first = try(data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_address_space[0], var.spoke_vnet_cidr_fallback)

  auto_routes_to_spoke = var.enable_route_to_spoke_vnet ? [
    {
      name                   = "to-spoke-workloads"
      address_prefix         = local.spoke_prefix_first
      next_hop_type          = var.spoke_route_next_hop_type
      next_hop_in_ip_address = var.spoke_route_next_hop_ip
    }
  ] : []

  all_routes = concat(var.custom_routes, local.auto_routes_to_spoke)
  routes_map = { for r in local.all_routes : r.name => r }

  subnet_resource_ids = var.associate_route_table_to_monitoring_subnet ? {
    monitoring_vm = data.terraform_remote_state.hub_monitoring_subnet.outputs.hub_subnet_id
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
