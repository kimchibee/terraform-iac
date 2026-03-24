output "hub_subnet_key" {
  description = "Hub VNet 서브넷 맵 키 (hub_subnets와 동일)"
  value       = local.subnet_name
}

output "hub_subnet_id" {
  description = "해당 서브넷 리소스 ID"
  value       = module.subnet.id
}

output "hub_subnet_name" {
  value = module.subnet.name
}

output "hub_subnet_address_prefixes" {
  value = module.subnet.address_prefixes
}

output "hub_vnet_id" {
  value = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_id
}

output "hub_resource_group_name" {
  value = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}
