#--------------------------------------------------------------
# Key Vault
#--------------------------------------------------------------
resource "azurerm_key_vault" "hub" {
  count = var.enable_key_vault ? 1 : 0

  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = true
  public_network_access_enabled = false
  tags                          = local.common_tags

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [
      var.monitoring_vm_subnet_id,
      var.pep_subnet_id
    ]
  }
}

#--------------------------------------------------------------
# Private Endpoint for Key Vault
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_key_vault ? 1 : 0

  name                = "pe-${var.key_vault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.pep_subnet_id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-${var.key_vault_name}"
    private_connection_resource_id = azurerm_key_vault.hub[0].id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [var.private_dns_zone_ids["vault"]]
  }
}

#--------------------------------------------------------------
# Role Assignment: VM Managed Identity → Key Vault
# Allow VM to read secrets from Key Vault
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = var.enable_monitoring_vm && var.enable_key_vault && var.monitoring_vm_identity_principal_id != "" ? 1 : 0

  scope                = azurerm_key_vault.hub[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.monitoring_vm_identity_principal_id
}

#--------------------------------------------------------------
# Role Assignment: VM Managed Identity → Key Vault (Reader)
# Allow VM to list keys and read Key Vault metadata
# Required for /keys API endpoint access
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = var.enable_monitoring_vm && var.enable_key_vault && var.monitoring_vm_identity_principal_id != "" ? 1 : 0

  scope                = azurerm_key_vault.hub[0].id
  role_definition_name = "Key Vault Reader"
  principal_id         = var.monitoring_vm_identity_principal_id
}
