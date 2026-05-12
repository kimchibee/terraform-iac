output "vm_id" {
  value = var.enable_vm ? module.vm[0].resource_id : null
}

output "vm_name" {
  value = var.enable_vm ? module.vm[0].name : null
}

output "vm_private_ip" {
  value = var.enable_vm ? try(module.vm[0].virtual_machine_azurerm.private_ip_address, null) : null
}

output "identity_principal_id" {
  value = var.enable_vm ? try(module.vm[0].system_assigned_mi_principal_id, null) : null
}

output "identity_tenant_id" {
  value = var.enable_vm ? try(module.vm[0].virtual_machine_azurerm.identity.tenant_id, null) : null
}
