#--------------------------------------------------------------
# Storage Module Outputs
#--------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID"
  value       = try(azurerm_key_vault.hub[0].id, null)
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = try(azurerm_key_vault.hub[0].vault_uri, null)
}

output "monitoring_storage_account_ids" {
  description = "Monitoring Storage Account IDs map"
  value = {
    for name, account in azurerm_storage_account.logs : name => account.id
  }
}
