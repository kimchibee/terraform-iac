#--------------------------------------------------------------
# Diagnostic Settings for Spoke Resources
# All logs are stored in Hub Storage Accounts via Private Endpoints
# Storage accounts and Private Endpoints are managed in Hub module
#--------------------------------------------------------------

#--------------------------------------------------------------
# Diagnostic Settings - Azure OpenAI to Hub Storage
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "openai_storage" {
  name               = "${var.openai_name}-storage-diag"
  target_resource_id = azurerm_cognitive_account.openai.id
  storage_account_id = var.hub_monitoring_storage_ids.openai

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  enabled_log {
    category = "Trace"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Diagnostic Settings - API Management to Hub Storage
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "apim_storage" {
  name               = "${var.apim_name}-storage-diag"
  target_resource_id = azurerm_api_management.main.id
  storage_account_id = var.hub_monitoring_storage_ids.apim

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Diagnostic Settings - AI Foundry (ML Workspace) to Hub Storage
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "aifoundry_storage" {
  name               = "${var.ai_foundry_name}-storage-diag"
  target_resource_id = azurerm_machine_learning_workspace.ai_foundry.id
  storage_account_id = var.hub_monitoring_storage_ids.aifoundry

  enabled_log {
    category = "AmlComputeClusterEvent"
  }

  enabled_log {
    category = "AmlComputeJobEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Diagnostic Settings - Container Registry to Hub Storage
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "acr_storage" {
  name               = "${var.ai_foundry_name}-acr-storage-diag"
  target_resource_id = azurerm_container_registry.ai_foundry.id
  storage_account_id = var.hub_monitoring_storage_ids.acr

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

#--------------------------------------------------------------
# Diagnostic Settings - Spoke Key Vault to Hub Storage
# Removed - using Hub Key Vault which already has diagnostic settings
#--------------------------------------------------------------
