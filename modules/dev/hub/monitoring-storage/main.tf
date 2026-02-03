#--------------------------------------------------------------
# Random suffix for unique storage account names
# Azure Storage Account names must be globally unique and lowercase
#--------------------------------------------------------------
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
  
  keepers = {
    # Force regeneration only if project_name changes
    project = var.project_name
  }
}

#--------------------------------------------------------------
# Storage Accounts for Logging (Hub + Spoke resources)
# All monitoring logs are stored in Hub via Private Endpoints
#--------------------------------------------------------------
resource "azurerm_storage_account" "logs" {
  for_each = local.storage_accounts

  name                          = "${each.value}${random_string.storage_suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = local.common_tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [
      var.monitoring_vm_subnet_id,
      var.pep_subnet_id
    ]
  }
}

#--------------------------------------------------------------
# Private Endpoints for Storage Accounts
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "storage_blob" {
  for_each = local.storage_accounts

  name                = "pe-${each.value}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pep_subnet_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-${each.value}-blob"
    private_connection_resource_id = azurerm_storage_account.logs[each.key].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["blob"]]
  }
}

#--------------------------------------------------------------
# Role Assignments: VM Managed Identity → Storage Accounts
# Allow VM to read/write logs from all storage accounts
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = var.enable_monitoring_vm && var.monitoring_vm_identity_principal_id != "" ? local.storage_accounts : {}

  scope                = azurerm_storage_account.logs[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.monitoring_vm_identity_principal_id
}
