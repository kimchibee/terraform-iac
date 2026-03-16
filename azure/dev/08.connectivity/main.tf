#--------------------------------------------------------------
# Connectivity Stack
# VNet Peering, Diagnostic Settings 등을 관리하는 스택
# AWS 방식: network, storage, shared-services 스택의 remote_state를 읽어서 의존성 해결
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Storage Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/02.storage/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Shared Services Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "shared_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/03.shared-services/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# VNet Peering: Hub → Spoke (Hub 구독에서 생성)
#--------------------------------------------------------------
module "vnet_peering_hub_to_spoke" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet-peering?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name                         = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-to-spoke"
  resource_group_name          = data.terraform_remote_state.network.outputs.hub_resource_group_name
  virtual_network_name         = data.terraform_remote_state.network.outputs.hub_vnet_name
  remote_virtual_network_id   = data.terraform_remote_state.network.outputs.spoke_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

#--------------------------------------------------------------
# VNet Peering: Spoke → Hub (Spoke 구독에서 생성, network 스택에서 이동)
#--------------------------------------------------------------
module "vnet_peering_spoke_to_hub" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet-peering?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                         = "${data.terraform_remote_state.network.outputs.spoke_vnet_name}-to-hub"
  resource_group_name          = data.terraform_remote_state.network.outputs.spoke_resource_group_name
  virtual_network_name         = data.terraform_remote_state.network.outputs.spoke_vnet_name
  remote_virtual_network_id   = data.terraform_remote_state.network.outputs.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true
}

#--------------------------------------------------------------
# Diagnostic Settings for Hub VNet Resources
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "hub_vpn_gateway" {
  count = length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? 1 : 0

  name               = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-vpng-storage-diag"
  target_resource_id = data.terraform_remote_state.network.outputs.hub_vpn_gateway_id
  storage_account_id = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["vpnglog"]

  enabled_log {
    category = "GatewayDiagnosticLog"
  }

  enabled_log {
    category = "TunnelDiagnosticLog"
  }

  enabled_log {
    category = "RouteDiagnosticLog"
  }

  enabled_log {
    category = "IKEDiagnosticLog"
  }

  enabled_log {
    category = "P2SDiagnosticLog"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_vnet" {
  count = length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? 1 : 0

  name               = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-storage-diag"
  target_resource_id = data.terraform_remote_state.network.outputs.hub_vnet_id
  storage_account_id = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["vnetlog"]

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_nsg_monitoring" {
  count = length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? 1 : 0

  name               = "${var.project_name}-nsg-monitoring-diag"
  target_resource_id = data.terraform_remote_state.network.outputs.hub_nsg_monitoring_vm_id
  storage_account_id = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["nsglog"]

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_nsg_pep" {
  count = length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? 1 : 0

  name               = "${var.project_name}-nsg-pep-diag"
  target_resource_id = data.terraform_remote_state.network.outputs.hub_nsg_pep_id
  storage_account_id = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["nsglog"]

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
