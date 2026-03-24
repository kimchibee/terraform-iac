# Spoke UDR ??공동 모듈 route-table ??AVM avm-res-network-routetable
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

data "terraform_remote_state" "spoke_apim_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/spoke-apim-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "spoke_pep_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/spoke-pep-subnet/terraform.tfstate"
  }
}

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

module "route_table" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/route-table?ref=chore/avm-wave1-modules-prune-and-convert"

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
