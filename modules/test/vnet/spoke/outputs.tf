#--------------------------------------------------------------
# Resource Group Outputs
#--------------------------------------------------------------
output "resource_group_name" {
  description = "Spoke resource group name"
  value       = azurerm_resource_group.spoke.name
}

output "resource_group_id" {
  description = "Spoke resource group ID"
  value       = azurerm_resource_group.spoke.id
}

#--------------------------------------------------------------
# Virtual Network Outputs
#--------------------------------------------------------------
output "vnet_id" {
  description = "Spoke VNet ID"
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Spoke VNet name"
  value       = azurerm_virtual_network.spoke.name
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

#--------------------------------------------------------------
# API Management Outputs
#--------------------------------------------------------------
output "apim_id" {
  description = "API Management ID"
  value       = azurerm_api_management.main.id
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_private_ip_addresses" {
  description = "API Management private IP addresses"
  value       = azurerm_api_management.main.private_ip_addresses
}

#--------------------------------------------------------------
# Azure OpenAI Outputs
#--------------------------------------------------------------
output "openai_id" {
  description = "Azure OpenAI ID"
  value       = azurerm_cognitive_account.openai.id
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = azurerm_cognitive_account.openai.endpoint
}

output "openai_primary_access_key" {
  description = "Azure OpenAI primary access key"
  value       = azurerm_cognitive_account.openai.primary_access_key
  sensitive   = true
}

#--------------------------------------------------------------
# AI Foundry Outputs
#--------------------------------------------------------------
output "ai_foundry_id" {
  description = "AI Foundry workspace ID"
  value       = azurerm_machine_learning_workspace.ai_foundry.id
}

output "ai_foundry_discovery_url" {
  description = "AI Foundry discovery URL"
  value       = azurerm_machine_learning_workspace.ai_foundry.discovery_url
}

#--------------------------------------------------------------
# Key Vault Outputs
#--------------------------------------------------------------
output "key_vault_id" {
  description = "AI Foundry Key Vault ID (using Hub Key Vault)"
  value       = var.hub_key_vault_id
}

#--------------------------------------------------------------
# Storage Account Outputs
#--------------------------------------------------------------
output "storage_account_id" {
  description = "AI Foundry Storage Account ID"
  value       = azurerm_storage_account.ai_foundry.id
}

#--------------------------------------------------------------
# Note: Monitoring Storage Accounts are centralized in Hub
# Spoke resources send logs to Hub storage via Private Endpoints
#--------------------------------------------------------------
