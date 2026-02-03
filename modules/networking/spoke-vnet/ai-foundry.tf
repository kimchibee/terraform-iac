#--------------------------------------------------------------
# Random suffix for AI Foundry resources
# Storage Account and ACR names must be globally unique
#--------------------------------------------------------------
resource "random_string" "ai_foundry_suffix" {
  length  = 4
  special = false
  upper   = false
  
  keepers = {
    project = var.project_name
    name    = var.ai_foundry_name
  }
}

#--------------------------------------------------------------
# Storage Account for AI Foundry
#--------------------------------------------------------------
resource "azurerm_storage_account" "ai_foundry" {
  name                          = "${replace(var.ai_foundry_name, "-", "")}st${random_string.ai_foundry_suffix.result}"
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = var.tags

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

#--------------------------------------------------------------
# Key Vault for AI Foundry
# Using Hub Key Vault instead of creating a new one in Spoke
#--------------------------------------------------------------

#--------------------------------------------------------------
# Application Insights for AI Foundry
#--------------------------------------------------------------
resource "azurerm_application_insights" "ai_foundry" {
  name                = "${var.ai_foundry_name}-ai"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : null
  tags                = var.tags
}

#--------------------------------------------------------------
# Container Registry for AI Foundry
#--------------------------------------------------------------
resource "azurerm_container_registry" "ai_foundry" {
  name                          = "${replace(var.ai_foundry_name, "-", "")}acr${random_string.ai_foundry_suffix.result}"
  resource_group_name           = azurerm_resource_group.spoke.name
  location                      = azurerm_resource_group.spoke.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  tags                          = var.tags

  network_rule_set {
    default_action = "Deny"
  }
}

#--------------------------------------------------------------
# Azure Machine Learning Workspace (AI Foundry)
#--------------------------------------------------------------
resource "azurerm_machine_learning_workspace" "ai_foundry" {
  name                          = var.ai_foundry_name
  location                      = azurerm_resource_group.spoke.location
  resource_group_name           = azurerm_resource_group.spoke.name
  application_insights_id       = azurerm_application_insights.ai_foundry.id
  key_vault_id                  = var.hub_key_vault_id
  storage_account_id            = azurerm_storage_account.ai_foundry.id
  container_registry_id         = azurerm_container_registry.ai_foundry.id
  public_network_access_enabled = false
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# Bing Search removed - not supported in this subscription/region

#--------------------------------------------------------------
# Private Endpoints for AI Foundry
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "ai_foundry" {
  name                = "pe-${var.ai_foundry_name}"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.subnets["pep-snet"].id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.ai_foundry_name}"
    private_connection_resource_id = azurerm_machine_learning_workspace.ai_foundry.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      var.private_dns_zone_ids["ml"],
      var.private_dns_zone_ids["notebooks"]
    ]
  }
}

resource "azurerm_private_endpoint" "ai_foundry_storage" {
  name                = "pe-${var.ai_foundry_name}-storage"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  subnet_id           = azurerm_subnet.subnets["pep-snet"].id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.ai_foundry_name}-storage"
    private_connection_resource_id = azurerm_storage_account.ai_foundry.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["blob"]]
  }
}

# Key Vault Private Endpoint removed - using Hub Key Vault which already has a Private Endpoint
