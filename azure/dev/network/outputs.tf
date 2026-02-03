#--------------------------------------------------------------
# Network Stack Outputs
# 다른 스택에서 terraform_remote_state로 참조
#--------------------------------------------------------------

# Hub VNet Outputs
output "hub_resource_group_name" {
  description = "Hub resource group name"
  value       = module.hub_vnet.resource_group_name
}

output "hub_resource_group_id" {
  description = "Hub resource group ID"
  value       = module.hub_vnet.resource_group_id
}

output "hub_vnet_id" {
  description = "Hub VNet ID"
  value       = module.hub_vnet.vnet_id
}

output "hub_vnet_name" {
  description = "Hub VNet name"
  value       = module.hub_vnet.vnet_name
}

output "hub_vnet_address_space" {
  description = "Hub VNet address space"
  value       = module.hub_vnet.vnet_address_space
}

output "hub_subnet_ids" {
  description = "Map of Hub subnet names to IDs"
  value       = module.hub_vnet.subnet_ids
}

output "hub_vpn_gateway_id" {
  description = "VPN Gateway ID"
  value       = module.hub_vnet.vpn_gateway_id
}

output "hub_vpn_gateway_public_ip" {
  description = "VPN Gateway public IP address"
  value       = module.hub_vnet.vpn_gateway_public_ip
}

output "hub_dns_resolver_id" {
  description = "DNS Private Resolver ID"
  value       = module.hub_vnet.dns_resolver_id
}

output "hub_dns_resolver_inbound_ip" {
  description = "DNS Resolver inbound endpoint IP"
  value       = module.hub_vnet.dns_resolver_inbound_ip
}

output "hub_private_dns_zone_ids" {
  description = "Map of Private DNS Zone IDs"
  value       = module.hub_vnet.private_dns_zone_ids
}

output "hub_private_dns_zone_names" {
  description = "Map of Private DNS Zone names"
  value       = module.hub_vnet.private_dns_zone_names
}

output "hub_nsg_monitoring_vm_id" {
  description = "Monitoring VM NSG ID"
  value       = module.hub_vnet.nsg_monitoring_vm_id
}

output "hub_nsg_pep_id" {
  description = "Private Endpoint NSG ID"
  value       = module.hub_vnet.nsg_pep_id
}

# Spoke VNet Outputs
output "spoke_resource_group_name" {
  description = "Spoke resource group name"
  value       = module.spoke_vnet.resource_group_name
}

output "spoke_resource_group_id" {
  description = "Spoke resource group ID"
  value       = module.spoke_vnet.resource_group_id
}

output "spoke_vnet_id" {
  description = "Spoke VNet ID"
  value       = module.spoke_vnet.vnet_id
}

output "spoke_vnet_name" {
  description = "Spoke VNet name"
  value       = module.spoke_vnet.vnet_name
}

output "spoke_vnet_address_space" {
  description = "Spoke VNet address space"
  value       = module.spoke_vnet.vnet_address_space
}

output "spoke_subnet_ids" {
  description = "Map of Spoke subnet names to IDs"
  value       = module.spoke_vnet.subnet_ids
}

# APIM, OpenAI, AI Foundry는 각각의 스택에서 출력
