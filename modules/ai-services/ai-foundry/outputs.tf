#--------------------------------------------------------------
# AI Foundry Outputs
# 이 모듈에서 외부로 반환하고 싶은 값 정의
# 다른 상위 모듈이나 파이프라인에서 참조할 수 있게 정리
#--------------------------------------------------------------

#--------------------------------------------------------------
# Machine Learning Workspace Outputs
#--------------------------------------------------------------
output "ai_foundry_id" {
  description = "AI Foundry workspace ID"
  value       = azurerm_machine_learning_workspace.ai_foundry.id
}

output "ai_foundry_name" {
  description = "AI Foundry workspace name"
  value       = azurerm_machine_learning_workspace.ai_foundry.name
}

output "ai_foundry_discovery_url" {
  description = "AI Foundry discovery URL"
  value       = azurerm_machine_learning_workspace.ai_foundry.discovery_url
}

output "ai_foundry_identity_principal_id" {
  description = "AI Foundry Managed Identity principal ID"
  value       = azurerm_machine_learning_workspace.ai_foundry.identity[0].principal_id
}

#--------------------------------------------------------------
# Storage Account Outputs
#--------------------------------------------------------------
output "storage_account_id" {
  description = "AI Foundry Storage Account ID"
  value       = azurerm_storage_account.ai_foundry.id
}

output "storage_account_name" {
  description = "AI Foundry Storage Account name"
  value       = azurerm_storage_account.ai_foundry.name
}

#--------------------------------------------------------------
# Container Registry Outputs
#--------------------------------------------------------------
output "container_registry_id" {
  description = "AI Foundry Container Registry ID"
  value       = azurerm_container_registry.ai_foundry.id
}

output "container_registry_name" {
  description = "AI Foundry Container Registry name"
  value       = azurerm_container_registry.ai_foundry.name
}

output "container_registry_login_server" {
  description = "AI Foundry Container Registry login server"
  value       = azurerm_container_registry.ai_foundry.login_server
}

#--------------------------------------------------------------
# Application Insights Outputs
#--------------------------------------------------------------
output "application_insights_id" {
  description = "AI Foundry Application Insights ID"
  value       = azurerm_application_insights.ai_foundry.id
}

output "application_insights_instrumentation_key" {
  description = "AI Foundry Application Insights instrumentation key"
  value       = azurerm_application_insights.ai_foundry.instrumentation_key
  sensitive   = true
}

#--------------------------------------------------------------
# Private Endpoint Outputs
#--------------------------------------------------------------
output "private_endpoint_ids" {
  description = "Map of Private Endpoint IDs"
  value = {
    workspace = azurerm_private_endpoint.ai_foundry.id
    storage   = azurerm_private_endpoint.ai_foundry_storage.id
  }
}
