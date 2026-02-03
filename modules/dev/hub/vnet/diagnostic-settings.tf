#--------------------------------------------------------------
# Diagnostic Settings for Hub Resources
# Each resource sends logs to its dedicated Storage Account
# via Private Endpoint (All storage accounts are in Hub)
#--------------------------------------------------------------

#--------------------------------------------------------------
# VPN Gateway Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vpn_gateway" {
  name               = "${var.vpn_gateway_name}-storage-diag"
  target_resource_id = azurerm_virtual_network_gateway.vpn.id
  storage_account_id = azurerm_storage_account.logs["vpnglog"].id

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

#--------------------------------------------------------------
# Key Vault Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name               = "${var.key_vault_name}-storage-diag"
  target_resource_id = azurerm_key_vault.hub[0].id
  storage_account_id = azurerm_storage_account.logs["kvlog"].id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# NSG Flow Logs for Monitoring VM Subnet
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "nsg_monitoring" {
  name               = "${var.project_name}-nsg-monitoring-diag"
  target_resource_id = azurerm_network_security_group.monitoring_vm.id
  storage_account_id = azurerm_storage_account.logs["nsglog"].id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

#--------------------------------------------------------------
# NSG Flow Logs for Private Endpoint Subnet
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "nsg_pep" {
  name               = "${var.project_name}-nsg-pep-diag"
  target_resource_id = azurerm_network_security_group.pep.id
  storage_account_id = azurerm_storage_account.logs["nsglog"].id

  enabled_log {
    category = "NetworkSecurityGroupEvent"
  }

  enabled_log {
    category = "NetworkSecurityGroupRuleCounter"
  }
}

#--------------------------------------------------------------
# Virtual Network Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "vnet" {
  name               = "${var.vnet_name}-storage-diag"
  target_resource_id = azurerm_virtual_network.hub.id
  storage_account_id = azurerm_storage_account.logs["vnetlog"].id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Storage Account Diagnostic Settings (for storage itself)
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "storage_blob" {
  for_each = local.storage_accounts

  name               = "${each.key}-blob-diag"
  target_resource_id = "${azurerm_storage_account.logs[each.key].id}/blobServices/default"
  storage_account_id = azurerm_storage_account.logs["stgstlog"].id

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
