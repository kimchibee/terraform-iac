#--------------------------------------------------------------
# Random suffix for unique storage account names
#--------------------------------------------------------------
resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

#--------------------------------------------------------------
# Storage Accounts for Logging (Hub + Spoke resources)
# All monitoring logs are stored in Hub via Private Endpoints
#--------------------------------------------------------------
locals {
  storage_accounts = {
    # Hub Resources
    "vpnglog"  = "${var.project_name}vpnglog"     # VPN Gateway logs
    "kvlog"    = "${var.project_name}kvlog"       # Hub Key Vault logs
    "nsglog"   = "${var.project_name}nsglog"      # NSG logs
    "vnetlog"  = "${var.project_name}vnetlog"     # VNet logs
    "vmlog"    = "${var.project_name}vmlog"       # VM logs
    "stgstlog" = "${var.project_name}stgstlog"    # Storage account logs (meta)
    # Spoke Resources (centralized in Hub)
    "aoailog"  = "${var.project_name}aoailog"     # Azure OpenAI logs
    "apimlog"  = "${var.project_name}apimlog"     # API Management logs
    "aiflog"   = "${var.project_name}aiflog"      # AI Foundry logs
    "acrlog"   = "${var.project_name}acrlog"      # Container Registry logs
    "spkvlog"  = "${var.project_name}spkvlog"     # Spoke Key Vault logs
  }
}

resource "azurerm_storage_account" "logs" {
  for_each = local.storage_accounts

  name                          = "${each.value}${random_string.storage_suffix.result}"
  resource_group_name           = azurerm_resource_group.hub.name
  location                      = azurerm_resource_group.hub.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = var.tags

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [
      azurerm_subnet.subnets["Monitoring-VM-Subnet"].id,
      azurerm_subnet.subnets["pep-snet"].id
    ]
  }
}

#--------------------------------------------------------------
# Key Vault
#--------------------------------------------------------------
resource "azurerm_key_vault" "hub" {
  count = var.enable_key_vault ? 1 : 0

  name                          = "${var.key_vault_name}${random_string.storage_suffix.result}"
  location                      = azurerm_resource_group.hub.location
  resource_group_name           = azurerm_resource_group.hub.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = false
  tags                          = var.tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [
      azurerm_subnet.subnets["Monitoring-VM-Subnet"].id,
      azurerm_subnet.subnets["pep-snet"].id
    ]
  }
}

#--------------------------------------------------------------
# Private Endpoints for Storage Accounts
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "storage_blob" {
  for_each = local.storage_accounts

  name                = "pe-${each.value}-blob"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = azurerm_subnet.subnets["pep-snet"].id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${each.value}-blob"
    private_connection_resource_id = azurerm_storage_account.logs[each.key].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["blob"].id]
  }
}

#--------------------------------------------------------------
# Private Endpoint for Key Vault
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name                = "pe-${var.key_vault_name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = azurerm_subnet.subnets["pep-snet"].id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.hub[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["vault"].id]
  }
}

#--------------------------------------------------------------
# Role Assignments: VM Managed Identity → Storage Accounts
# Allow VM to read/write logs from all storage accounts
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = var.enable_monitoring_vm ? local.storage_accounts : {}

  scope                = azurerm_storage_account.logs[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

#--------------------------------------------------------------
# Role Assignment: VM Managed Identity → Key Vault
# Allow VM to read secrets from Key Vault
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = var.enable_monitoring_vm && var.enable_key_vault ? 1 : 0

  scope                = azurerm_key_vault.hub[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

#--------------------------------------------------------------
# Role Assignment: VM Managed Identity → Key Vault (Reader)
# Allow VM to list keys and read Key Vault metadata
# Required for /keys API endpoint access
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = var.enable_monitoring_vm && var.enable_key_vault ? 1 : 0

  scope                = azurerm_key_vault.hub[0].id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}

#--------------------------------------------------------------
# Role Assignment: VM Managed Identity → Resource Group (Reader)
# Allow VM to access Management Plane API (read resource information)
# This is required for Azure CLI and REST API calls to list/describe resources
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_reader" {
  count = var.enable_monitoring_vm ? 1 : 0

  scope                = azurerm_resource_group.hub.id
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id
}
