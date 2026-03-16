output "vm_id" {
  value = var.enable_vm ? module.vm[0].vm_id : null
}

output "vm_name" {
  value = var.enable_vm ? module.vm[0].vm_name : null
}

output "vm_private_ip" {
  value = var.enable_vm ? module.vm[0].vm_private_ip : null
}

output "identity_principal_id" {
  value = var.enable_vm ? module.vm[0].identity_principal_id : null
}

output "identity_tenant_id" {
  value = var.enable_vm ? module.vm[0].identity_tenant_id : null
}
