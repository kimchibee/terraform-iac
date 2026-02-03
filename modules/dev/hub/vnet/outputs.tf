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
# VM Outputs
#--------------------------------------------------------------
output "monitoring_vm_id" {
  description = "Monitoring VM ID"
  value       = var.enable_monitoring_vm ? azurerm_linux_virtual_machine.monitoring[0].id : null
}

output "monitoring_vm_private_ip" {
  description = "Monitoring VM private IP"
  value       = var.enable_monitoring_vm ? azurerm_network_interface.monitoring_vm[0].private_ip_address : null
}

output "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity principal ID"
  value       = var.enable_monitoring_vm ? azurerm_linux_virtual_machine.monitoring[0].identity[0].principal_id : null
}

#--------------------------------------------------------------
# Key Vault Outputs
#--------------------------------------------------------------
output "key_vault_id" {
  description = "Key Vault ID"
  value       = var.enable_key_vault ? azurerm_key_vault.hub[0].id : null
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = var.enable_key_vault ? azurerm_key_vault.hub[0].vault_uri : null
}

#--------------------------------------------------------------
# Storage Account Outputs
#--------------------------------------------------------------
output "storage_account_ids" {
  description = "Map of storage account IDs"
  value       = { for k, v in azurerm_storage_account.logs : k => v.id }
}

output "monitoring_storage_account_ids" {
  description = "Map of monitoring storage account IDs for Spoke resources"
  value = {
    openai     = azurerm_storage_account.logs["aoailog"].id
    apim       = azurerm_storage_account.logs["apimlog"].id
    aifoundry  = azurerm_storage_account.logs["aiflog"].id
    acr        = azurerm_storage_account.logs["acrlog"].id
    spoke_kv   = azurerm_storage_account.logs["spkvlog"].id
  }
}

#--------------------------------------------------------------
# Bastion Host Outputs
#--------------------------------------------------------------
output "bastion_host_id" {
  description = "Bastion Host ID"
  value       = azurerm_bastion_host.hub.id
}

output "bastion_host_fqdn" {
  description = "Bastion Host FQDN"
  value       = azurerm_bastion_host.hub.dns_name
}
