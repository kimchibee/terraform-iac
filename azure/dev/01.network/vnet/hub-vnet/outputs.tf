#--------------------------------------------------------------
# Hub VNet 리프 Outputs
#--------------------------------------------------------------

output "hub_resource_group_name" {
  description = "Hub resource group name"
  value       = data.terraform_remote_state.hub_rg.outputs.resource_group_name
}

output "hub_resource_group_id" {
  description = "Hub resource group ID"
  value       = data.terraform_remote_state.hub_rg.outputs.resource_group_id
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
