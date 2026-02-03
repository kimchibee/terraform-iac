#--------------------------------------------------------------
# Random suffix for unique APIM name
# API Management names must be globally unique
#--------------------------------------------------------------
resource "random_string" "apim_suffix" {
  length  = 4
  special = false
  upper   = false
  
  keepers = {
    project = var.project_name
    name    = var.apim_name
  }
}

#--------------------------------------------------------------
# API Management
#--------------------------------------------------------------
resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
  virtual_network_type = "Internal"
  tags                = local.common_tags

  virtual_network_configuration {
    subnet_id = data.azurerm_subnet.apim.id
  }

  identity {
    type = "SystemAssigned"
  }
}

# Note: Private Endpoint for APIM is NOT needed when using Internal VNet mode
# APIM in Internal mode is already only accessible from within the VNet

#--------------------------------------------------------------
# APIs (if configured)
#--------------------------------------------------------------
resource "azurerm_api_management_api" "apis" {
  for_each = var.apis

  name                = each.key
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  revision            = "1"
  display_name        = each.value.display_name
  path                = each.value.path
  protocols           = each.value.protocols
  service_url         = each.value.service_url != "" ? each.value.service_url : null
}

#--------------------------------------------------------------
# API Policies (if configured)
#--------------------------------------------------------------
resource "azurerm_api_management_api_policy" "api_policies" {
  for_each = {
    for k, v in var.apis : k => v
    if v.policy_file != null && v.policy_file != ""
  }

  api_name            = azurerm_api_management_api.apis[each.key].name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = file(each.value.policy_file)
}

#--------------------------------------------------------------
# Global Policy (if configured)
#--------------------------------------------------------------
resource "azurerm_api_management_policy" "global" {
  count = local.policy_files.global_policy != "" ? 1 : 0

  api_management_id = azurerm_api_management.main.id
  xml_content       = file(local.policy_files.global_policy)
}

#--------------------------------------------------------------
# API Management Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "apim" {
  count = var.log_analytics_workspace_id != "" ? 1 : 0

  name                       = "${local.apim_name}-diag"
  target_resource_id         = azurerm_api_management.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

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
