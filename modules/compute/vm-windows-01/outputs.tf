#--------------------------------------------------------------
# Windows VM Instance Outputs
#--------------------------------------------------------------

output "vm_id" {
  description = "VM ID"
  value       = module.vm.vm_id
}

output "vm_name" {
  description = "VM 이름"
  value       = module.vm.vm_name
}

output "vm_private_ip" {
  description = "VM Private IP 주소"
  value       = module.vm.vm_private_ip
}

output "network_interface_id" {
  description = "Network Interface ID"
  value       = module.vm.network_interface_id
}

output "identity_principal_id" {
  description = "Managed Identity Principal ID"
  value       = module.vm.identity_principal_id
}

output "identity_tenant_id" {
  description = "Managed Identity Tenant ID"
  value       = module.vm.identity_tenant_id
}
