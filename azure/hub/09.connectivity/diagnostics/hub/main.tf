resource "azurerm_monitor_diagnostic_setting" "hub_vpn_gateway" {
  count = local.diag_storage_account_id != null && local.hub_vpn_gateway_id != null ? 1 : 0

  name               = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-vpng-storage-diag"
  target_resource_id = local.hub_vpn_gateway_id
  storage_account_id = local.diag_storage_account_id

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
  count = local.diag_storage_account_id != null ? 1 : 0

  name               = "${data.terraform_remote_state.network.outputs.hub_vnet_name}-storage-diag"
  target_resource_id = data.terraform_remote_state.network.outputs.hub_vnet_id
  storage_account_id = local.diag_storage_account_id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_nsg_monitoring" {
  count = local.diag_storage_account_id != null ? 1 : 0

  name               = "${var.project_name}-nsg-monitoring-diag"
  target_resource_id = data.terraform_remote_state.hub_monitoring_nsg.outputs.network_security_group_id
  storage_account_id = local.diag_storage_account_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_nsg_pep" {
  count = local.diag_storage_account_id != null ? 1 : 0

  name               = "${var.project_name}-nsg-pep-diag"
  target_resource_id = data.terraform_remote_state.hub_pep_nsg.outputs.network_security_group_id
  storage_account_id = local.diag_storage_account_id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}
