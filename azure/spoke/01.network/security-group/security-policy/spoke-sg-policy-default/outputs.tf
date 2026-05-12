output "spoke_firewall_policy_id" {
  description = "Spoke Azure Firewall Policy 리소스 ID"
  value       = module.firewall_policy.resource_id
}

output "spoke_firewall_policy_name" {
  value = module.firewall_policy.resource.name
}

output "spoke_firewall_id" {
  description = "Spoke Azure Firewall 리소스 ID (deploy_azure_firewall = false 이면 null)"
  value       = var.deploy_azure_firewall ? azurerm_firewall.spoke[0].id : null
}

output "spoke_firewall_private_ip" {
  description = "Spoke Azure Firewall 프라이빗 IP — UDR next hop 용"
  value       = var.deploy_azure_firewall ? azurerm_firewall.spoke[0].ip_configuration[0].private_ip_address : null
}

output "spoke_firewall_public_ip" {
  description = "Spoke Azure Firewall 공인 IP"
  value       = var.deploy_azure_firewall ? azurerm_public_ip.firewall[0].ip_address : null
}
