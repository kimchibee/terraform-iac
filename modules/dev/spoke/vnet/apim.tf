#--------------------------------------------------------------
# Random suffix for unique APIM name
#--------------------------------------------------------------
resource "random_string" "apim_suffix" {
  length  = 4
  special = false
  upper   = false
  
  keepers = {
    # Force regeneration only if apim_name changes
    apim_name = var.apim_name
  }
}

#--------------------------------------------------------------
# API Management
#--------------------------------------------------------------
resource "azurerm_api_management" "main" {
  name                          = "${var.apim_name}-${random_string.apim_suffix.result}"
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  publisher_name                = var.apim_publisher_name
  publisher_email               = var.apim_publisher_email
  sku_name                      = var.apim_sku_name
  virtual_network_type          = "Internal"
  tags                          = var.tags

  virtual_network_configuration {
    subnet_id = azurerm_subnet.subnets["apim-snet"].id
  }

  identity {
    type = "SystemAssigned"
  }
}

# Note: Private Endpoint for APIM is NOT needed when using Internal VNet mode
# APIM in Internal mode is already only accessible from within the VNet

#--------------------------------------------------------------
# API Management Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "${var.apim_name}-diag"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
