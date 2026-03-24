#--------------------------------------------------------------
# AI Services Stack Outputs
#--------------------------------------------------------------

output "openai_id" {
  description = "Azure OpenAI ID"
  value       = module.openai.id
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = module.openai.endpoint
}

output "ai_foundry_id" {
  description = "Deferred output (AI Foundry workspace not provisioned in wave1)"
  value       = null
}

output "ai_foundry_discovery_url" {
  description = "Deferred output (AI Foundry workspace not provisioned in wave1)"
  value       = null
}

output "key_vault_id" {
  description = "Deferred output (AI Foundry workspace not provisioned in wave1)"
  value       = null
}

output "storage_account_id" {
  description = "Deferred output (AI Foundry workspace not provisioned in wave1)"
  value       = null
}
