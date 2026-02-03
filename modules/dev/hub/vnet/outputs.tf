#--------------------------------------------------------------
# Resource Group Outputs
#--------------------------------------------------------------
output "resource_group_name" {
  description = "Hub resource group name"
  value       = azurerm_resource_group.hub.name
}

output "resource_group_id" {
  description = "Hub resource group ID"
  value       = azurerm_resource_group.hub.id
}

#--------------------------------------------------------------
# Virtual Network Outputs
#--------------------------------------------------------------
output "vnet_id" {
  description = "Hub VNet ID"
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Hub VNet name"
  value       = azurerm_virtual_network.hub.name
}

output "vnet_address_space" {
  description = "Hub VNet address space"
  value       = azurerm_virtual_network.hub.address_space
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = { for k, v in azurerm_subnet.subnets : k => v.id }
}

#--------------------------------------------------------------
# VPN Gateway Outputs
#--------------------------------------------------------------
output "vpn_gateway_id" {
  description = "VPN Gateway ID"
  value       = azurerm_virtual_network_gateway.vpn.id
}

output "vpn_gateway_public_ip" {
  description = "VPN Gateway public IP address"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

#--------------------------------------------------------------
# DNS Resolver Outputs
#--------------------------------------------------------------
output "dns_resolver_id" {
  description = "DNS Private Resolver ID"
  value       = azurerm_private_dns_resolver.hub.id
}

output "dns_resolver_inbound_ip" {
  description = "DNS Resolver inbound endpoint IP"
  value       = azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address
}

#--------------------------------------------------------------
# Private DNS Zone Outputs
#--------------------------------------------------------------
output "private_dns_zone_ids" {
  description = "Map of Private DNS Zone IDs"
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}

output "private_dns_zone_names" {
  description = "Map of Private DNS Zone names"
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.name }
}

#--------------------------------------------------------------
# Network Security Group Outputs
#--------------------------------------------------------------
output "nsg_monitoring_vm_id" {
  description = "Monitoring VM NSG ID"
  value       = azurerm_network_security_group.monitoring_vm.id
}

output "nsg_pep_id" {
  description = "Private Endpoint NSG ID"
  value       = azurerm_network_security_group.pep.id
}

#--------------------------------------------------------------
# VM Outputs (Removed - VM is managed by root module monitoring_vm)
#--------------------------------------------------------------
# Monitoring VM은 루트 main.tf의 module.monitoring_vm에서 관리됨

#--------------------------------------------------------------
# Key Vault Outputs (Removed - Key Vault is managed by storage module)
#--------------------------------------------------------------
# Key Vault는 modules/dev/hub/monitoring-storage 모듈에서 관리됨

#--------------------------------------------------------------
# Storage Account Outputs (Removed - Storage is managed by storage module)
#--------------------------------------------------------------
# Storage Account는 modules/dev/hub/monitoring-storage 모듈에서 관리됨

#--------------------------------------------------------------
# Bastion Host Outputs (Removed - Not used in current architecture)
#--------------------------------------------------------------
# Bastion Host는 현재 아키텍처에서 사용하지 않음
