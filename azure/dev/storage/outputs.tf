#--------------------------------------------------------------
# Storage Stack Outputs
# 다른 스택에서 terraform_remote_state로 참조
#--------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID"
  value       = module.storage.key_vault_id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.storage.key_vault_uri
}

output "monitoring_storage_account_ids" {
  description = "Monitoring Storage Account IDs map"
  value       = module.storage.monitoring_storage_account_ids
}
