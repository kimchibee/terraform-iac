#--------------------------------------------------------------
# Bootstrap Backend Outputs
#--------------------------------------------------------------

output "resource_group_name" {
  description = "Backend resource group name"
  value       = azurerm_resource_group.backend.name
}

output "storage_account_name" {
  description = "Backend storage account name"
  value       = azurerm_storage_account.tf_state.name
}

output "container_name" {
  description = "Backend container name"
  value       = azurerm_storage_container.tfstate.name
}

output "storage_account_id" {
  description = "Backend storage account ID"
  value       = azurerm_storage_account.tf_state.id
}
