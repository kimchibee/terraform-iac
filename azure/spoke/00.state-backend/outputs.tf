output "resource_group_name" {
  description = "Spoke state backend RG — paste into each Spoke leaf's tfvars as spoke_backend_resource_group_name"
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Spoke state backend SA — paste into each Spoke leaf's tfvars as spoke_backend_storage_account_name"
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Spoke state backend container — paste into each Spoke leaf's tfvars as spoke_backend_container_name"
  value       = azurerm_storage_container.state.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL of the Spoke state storage account"
  value       = azurerm_storage_account.state.primary_blob_endpoint
}
