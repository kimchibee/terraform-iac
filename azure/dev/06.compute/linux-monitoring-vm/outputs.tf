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

output "monitoring_vm_identity_principal_id" {
  description = "storage / 08.rbac remote_state용 (기존 compute 루트 output 이름과 동일)"
  value       = var.enable_vm ? module.vm[0].identity_principal_id : null
}

output "identity_tenant_id" {
  value = var.enable_vm ? module.vm[0].identity_tenant_id : null
}

output "ssh_private_key_path" {
  value = var.enable_vm ? "${path.root}/${var.ssh_private_key_filename}" : null
}
