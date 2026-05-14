output "resource_group_name" {
  description = "State backend RG name — set scripts/import/env.sh TF_BACKEND_RG to this value"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "State backend SA name — set scripts/import/env.sh TF_BACKEND_SA to this value"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "State backend container name — set scripts/import/env.sh TF_BACKEND_CONTAINER to this value"
  value       = azurerm_storage_container.state.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL of the state storage account"
  value       = azurerm_storage_account.state.primary_blob_endpoint
}
