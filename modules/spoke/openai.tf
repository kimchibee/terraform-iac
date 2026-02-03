#--------------------------------------------------------------
# Azure OpenAI Cognitive Service
# Note: Using fixed suffix "bt77" to match existing Azure resource (test-x-x-aoaibt77)
#--------------------------------------------------------------
resource "azurerm_cognitive_account" "openai" {
  name                          = "${var.openai_name}bt77"  # Fixed to match existing: test-x-x-aoaibt77
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  kind                          = "OpenAI"
  sku_name                      = var.openai_sku
  custom_subdomain_name         = "${var.openai_name}bt77"  # Fixed to match existing
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action = "Deny"
    ip_rules       = []
  }

  identity {
    type = "SystemAssigned"
  }
}

#--------------------------------------------------------------
# Azure OpenAI Model Deployments
#--------------------------------------------------------------
resource "azurerm_cognitive_deployment" "models" {
  for_each = { for d in var.openai_deployments : d.name => d }

  name                 = each.value.name
  cognitive_account_id = azurerm_cognitive_account.openai.id

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.version
  }

  scale {
    type     = "GlobalStandard"
    capacity = each.value.capacity
  }
}

#--------------------------------------------------------------
# Private Endpoint for Azure OpenAI
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "openai" {
  name                = "pe-${var.openai_name}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.subnets["pep-snet"].id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.openai_name}"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["openai"]]
  }
}

#--------------------------------------------------------------
# Azure OpenAI Diagnostic Settings
#--------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "openai" {
  name                       = "${var.openai_name}-diag"
  target_resource_id         = azurerm_cognitive_account.openai.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
