#--------------------------------------------------------------
# Storage Stack Outputs
# 다른 스택에서 terraform_remote_state로 참조
#--------------------------------------------------------------

output "key_vault_id" {
  description = "Key Vault ID"
  value       = var.enable_key_vault ? module.key_vault[0].resource_id : null
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = var.enable_key_vault ? module.key_vault[0].uri : null
}

output "monitoring_storage_account_ids" {
  description = "Monitoring Storage Account IDs map"
  value       = { for k, v in module.monitoring_storage : k => v.resource_id }
}
