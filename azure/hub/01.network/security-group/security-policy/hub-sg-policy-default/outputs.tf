output "hub_firewall_policy_id" {
  description = "Hub Azure Firewall Policy 리소스 ID — 추가 규칙 컬렉션·연동 시 참조"
  value       = module.firewall_policy.resource_id
}

output "hub_firewall_policy_name" {
  value = module.firewall_policy.resource.name
}

output "hub_firewall_id" {
  description = "Azure Firewall 리소스 ID (deploy_azure_firewall = false 이면 null)"
  value       = var.deploy_azure_firewall ? azurerm_firewall.hub[0].id : null
}

output "hub_firewall_private_ip" {
  description = "Azure Firewall 프라이빗 IP — UDR next hop 용"
  value       = var.deploy_azure_firewall ? azurerm_firewall.hub[0].ip_configuration[0].private_ip_address : null
}

output "hub_firewall_public_ip" {
  description = "Azure Firewall 공인 IP (문자열)"
  value       = var.deploy_azure_firewall ? azurerm_public_ip.firewall[0].ip_address : null
}
