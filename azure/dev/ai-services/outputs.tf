#--------------------------------------------------------------
# AI Services Stack Outputs
#--------------------------------------------------------------

output "openai_id" {
  description = "Azure OpenAI ID"
  value       = module.ai_services.openai_id
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = module.ai_services.openai_endpoint
}

output "ai_foundry_id" {
  description = "AI Foundry workspace ID"
  value       = module.ai_services.ai_foundry_id
}

output "ai_foundry_discovery_url" {
  description = "AI Foundry discovery URL"
  value       = module.ai_services.ai_foundry_discovery_url
}

output "key_vault_id" {
  description = "Key Vault ID (Hub Key Vault used by AI Foundry)"
  value       = module.ai_services.key_vault_id
}

output "storage_account_id" {
  description = "Storage Account ID (AI Foundry Storage)"
  value       = module.ai_services.storage_account_id
}
