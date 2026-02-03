#-------------------------------------------------------------------------------
# Resource Group 모듈 - 출력
#-------------------------------------------------------------------------------

output "id" {
  description = "Resource Group ID"
  value       = azurerm_resource_group.main.id
}

output "name" {
  description = "Resource Group 이름"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Resource Group 위치"
  value       = azurerm_resource_group.main.location
}
