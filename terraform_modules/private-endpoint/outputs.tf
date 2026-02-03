#-------------------------------------------------------------------------------
# Private Endpoint 모듈 - 출력
#-------------------------------------------------------------------------------

output "id" {
  description = "Private Endpoint 리소스 ID"
  value       = azurerm_private_endpoint.main.id
}

output "name" {
  description = "Private Endpoint 이름"
  value       = azurerm_private_endpoint.main.name
}

output "private_ip_address" {
  description = "Private Endpoint에 할당된 프라이빗 IP"
  value       = azurerm_private_endpoint.main.private_service_connection[0].private_ip_address
}
