# Hub 측 모니터링 진단 설정 (VPN Gateway, VNet, NSG)
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_vpn_gateway" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/virtual-network-gateway/hub-vpn-gateway/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_monitoring_nsg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/network-security-group/hub-monitoring-vm/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_pep_nsg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/network-security-group/hub-pep/terraform.tfstate"
  }
}

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/02.storage/monitoring/terraform.tfstate"
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_vpn_gateway" {
  count = length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? 1 : 0

  name               = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-vpng-storage-diag"
  target_resource_id = data.terraform_remote_state.hub_vpn_gateway.outputs.virtual_network_gateway_id
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
  target_resource_id = data.terraform_remote_state.hub_monitoring_nsg.outputs.network_security_group_id
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
  target_resource_id = data.terraform_remote_state.hub_pep_nsg.outputs.network_security_group_id
  storage_account_id = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["nsglog"]

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
