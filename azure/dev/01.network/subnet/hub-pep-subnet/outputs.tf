output "hub_subnet_key" {
  value = local.subnet_name
}

output "hub_subnet_id" {
  value = module.subnet.resource_id
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

output "keyvault_sg_nsg_id" {
  description = "Standalone keyvault-sg NSG ID"
  value       = null
}

output "keyvault_clients_asg_id" {
  description = "Key Vault 접근 허용 ASG ID"
  value       = try(data.terraform_remote_state.sg_hub_keyvault_clients_asg.outputs.keyvault_clients_asg_id, null)
}

output "vm_allowed_clients_asg_id" {
  description = "VM 접속 허용 클라이언트 ASG ID (Spoke subnet 리프·compute에서 참조)"
  value       = try(data.terraform_remote_state.sg_hub_vm_allowed_clients_asg.outputs.vm_allowed_clients_asg_id, null)
}
