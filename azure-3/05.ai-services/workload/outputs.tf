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
  description = "Azure Machine Learning workspace (AI Foundry) ID"
  value       = try(azurerm_machine_learning_workspace.ai_foundry[0].id, null)
}

output "ai_foundry_discovery_url" {
  description = "AI Foundry discovery URL"
  value       = try(azurerm_machine_learning_workspace.ai_foundry[0].discovery_url, null)
}

output "key_vault_id" {
  description = "AI Foundry dependency Key Vault ID"
  value       = azurerm_key_vault.ai_foundry.id
}

output "storage_account_id" {
  description = "AI Foundry dependency Storage Account ID"
  value       = azurerm_storage_account.ai_foundry.id
}

output "openai_private_endpoint_id" {
  description = "OpenAI Private Endpoint ID in spoke"
  value       = try(module.openai_private_endpoint[0].id, null)
}

output "ai_foundry_private_endpoint_id" {
  description = "AI Foundry Private Endpoint ID in spoke"
  value       = try(module.ai_foundry_private_endpoint[0].id, null)
}
