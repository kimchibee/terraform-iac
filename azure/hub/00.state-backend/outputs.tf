output "resource_group_name" {
  description = "Hub state backend RG — paste into each Hub leaf's tfvars as hub_backend_resource_group_name"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Hub state backend SA — paste into each Hub leaf's tfvars as hub_backend_storage_account_name"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Hub state backend container — paste into each Hub leaf's tfvars as hub_backend_container_name"
  value       = azurerm_storage_container.state.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL of the Hub state storage account"
  value       = azurerm_storage_account.state.primary_blob_endpoint
}
