output "spoke_resource_group_name" {
  description = "Spoke resource group name"
  value       = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
}

output "spoke_resource_group_id" {
  description = "Spoke resource group ID"
  value       = data.terraform_remote_state.spoke_rg.outputs.resource_group_id
}

output "spoke_vnet_id" {
  description = "Spoke VNet ID"
  value       = module.spoke_vnet.resource_id
}

output "spoke_vnet_name" {
  description = "Spoke VNet name"
  value       = module.spoke_vnet.name
}

output "spoke_vnet_address_space" {
  description = "Spoke VNet address space"
  value = try(
    module.spoke_vnet.resource.output.properties.addressSpace.addressPrefixes,
    module.spoke_vnet.resource.body.properties.addressSpace.addressPrefixes
  )
}
