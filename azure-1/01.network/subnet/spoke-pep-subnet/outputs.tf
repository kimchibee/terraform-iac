output "spoke_subnet_key" {
  description = "Spoke VNet 서브넷 맵 키 (subnets와 동일)"
  value       = local.subnet_name
}

output "spoke_subnet_id" {
  description = "해당 서브넷 리소스 ID"
  value       = module.subnet.resource_id
}

output "spoke_subnet_name" {
  value = module.subnet.name
}

output "spoke_subnet_address_prefixes" {
  value = module.subnet.address_prefixes
}

output "spoke_vnet_id" {
  value = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_id
}

output "spoke_resource_group_name" {
  value = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
}
