#--------------------------------------------------------------
# API Management Outputs
# 이 모듈에서 외부로 반환하고 싶은 값 정의
# 다른 상위 모듈이나 파이프라인에서 참조할 수 있게 정리
#--------------------------------------------------------------

#--------------------------------------------------------------
# API Management Outputs
#--------------------------------------------------------------
output "apim_id" {
  description = "API Management ID"
  value       = azurerm_api_management.main.id
}

output "apim_name" {
  description = "API Management name"
  value       = azurerm_api_management.main.name
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = azurerm_api_management.main.gateway_url
}

output "apim_management_api_url" {
  description = "API Management management API URL"
  value       = azurerm_api_management.main.management_api_url
}

output "apim_private_ip_addresses" {
  description = "API Management private IP addresses"
  value       = azurerm_api_management.main.private_ip_addresses
}

output "apim_public_ip_addresses" {
  description = "API Management public IP addresses"
  value       = azurerm_api_management.main.public_ip_addresses
}

output "apim_identity_principal_id" {
  description = "API Management Managed Identity principal ID"
  value       = azurerm_api_management.main.identity[0].principal_id
}

#--------------------------------------------------------------
# API Outputs (if APIs are created)
#--------------------------------------------------------------
output "api_ids" {
  description = "Map of API IDs"
  value       = { for k, v in azurerm_api_management_api.apis : k => v.id }
}

output "api_urls" {
  description = "Map of API URLs"
  value       = { for k, v in azurerm_api_management_api.apis : k => "${azurerm_api_management.main.gateway_url}/${v.path}" }
}
