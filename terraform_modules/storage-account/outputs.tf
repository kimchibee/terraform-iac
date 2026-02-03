#-------------------------------------------------------------------------------
# Storage Account 모듈 - 출력
#-------------------------------------------------------------------------------

output "storage_account_id" {
  description = "Storage Account 리소스 ID"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Storage Account 이름"
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Blob Primary Endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_access_key" {
  description = "Primary Access Key (민감 정보)"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}
