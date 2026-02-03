#--------------------------------------------------------------
# Hub Outputs
#--------------------------------------------------------------
output "hub_resource_group_name" {
  description = "Hub resource group name"
  value       = module.hub_vnet.resource_group_name
}

output "hub_vnet_id" {
  description = "Hub VNet ID"
  value       = module.hub_vnet.vnet_id
}

output "hub_vnet_name" {
  description = "Hub VNet name"
  value       = module.hub_vnet.vnet_name
}

output "hub_subnet_ids" {
  description = "Hub subnet IDs"
  value       = module.hub_vnet.subnet_ids
}

output "vpn_gateway_public_ip" {
  description = "VPN Gateway public IP address"
  value       = module.hub_vnet.vpn_gateway_public_ip
}

output "dns_resolver_inbound_ip" {
  description = "DNS Resolver inbound endpoint IP"
  value       = module.hub_vnet.dns_resolver_inbound_ip
}

output "monitoring_vm_private_ip" {
  description = "Monitoring VM private IP"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].vm_private_ip : null
}

output "key_vault_uri" {
  description = "Hub Key Vault URI"
  value       = module.storage.key_vault_uri
}

#--------------------------------------------------------------
# Spoke Outputs
#--------------------------------------------------------------
output "spoke_resource_group_name" {
  description = "Spoke resource group name"
  value       = module.spoke_vnet.resource_group_name
}

output "spoke_vnet_id" {
  description = "Spoke VNet ID"
  value       = module.spoke_vnet.vnet_id
}

output "spoke_vnet_name" {
  description = "Spoke VNet name"
  value       = module.spoke_vnet.vnet_name
}

output "spoke_subnet_ids" {
  description = "Spoke subnet IDs"
  value       = module.spoke_vnet.subnet_ids
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.spoke_vnet.apim_gateway_url
}

output "apim_private_ip_addresses" {
  description = "API Management private IP addresses"
  value       = module.spoke_vnet.apim_private_ip_addresses
}

output "openai_endpoint" {
  description = "Azure OpenAI endpoint"
  value       = module.spoke_vnet.openai_endpoint
}

output "ai_foundry_discovery_url" {
  description = "AI Foundry discovery URL"
  value       = module.spoke_vnet.ai_foundry_discovery_url
}

#--------------------------------------------------------------
# Monitoring Storage Outputs (Centralized in Hub)
#--------------------------------------------------------------
output "monitoring_storage_accounts" {
  description = "Hub monitoring storage accounts (centralized for all resources)"
  value       = module.storage.monitoring_storage_account_ids
}

#--------------------------------------------------------------
# Shared Services Outputs
#--------------------------------------------------------------
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.shared_services.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = module.shared_services.log_analytics_workspace_name
}

#--------------------------------------------------------------
# Connection Information
#--------------------------------------------------------------
output "connection_info" {
  description = "Connection information summary"
  value = {
    vpn_gateway_ip        = module.hub_vnet.vpn_gateway_public_ip
    dns_resolver_ip       = module.hub_vnet.dns_resolver_inbound_ip
    apim_private_ips      = module.spoke_vnet.apim_private_ip_addresses
    openai_endpoint       = module.spoke_vnet.openai_endpoint
    ai_foundry_url        = module.spoke_vnet.ai_foundry_discovery_url
  }
}
