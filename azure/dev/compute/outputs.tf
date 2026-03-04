#--------------------------------------------------------------
# Compute Stack Outputs
# 다른 스택에서 terraform_remote_state로 참조
#--------------------------------------------------------------

output "monitoring_vm_id" {
  description = "Monitoring VM ID"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].vm_id : null
}

output "monitoring_vm_name" {
  description = "Monitoring VM name"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].vm_name : null
}

output "monitoring_vm_private_ip" {
  description = "Monitoring VM private IP"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].vm_private_ip : null
}

output "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity Principal ID"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].identity_principal_id : null
}

output "monitoring_vm_identity_tenant_id" {
  description = "Monitoring VM Managed Identity Tenant ID"
  value       = var.enable_monitoring_vm ? module.monitoring_vm[0].identity_tenant_id : null
}

# PEM 키 경로 및 SSH 접속 안내 (apply 후 이 키로 VM 접속)
output "monitoring_vm_ssh_private_key_path" {
  description = "Monitoring VM SSH 접속용 개인키 파일 경로 (이 파일로 SSH 접속)"
  value       = var.enable_monitoring_vm ? "${path.module}/${var.vm_ssh_private_key_filename}" : null
}

output "monitoring_vm_ssh_command" {
  description = "SSH 접속 예시 (Bastion/Private IP 등으로 접근 가능한 경우)"
  value       = var.enable_monitoring_vm ? "ssh -i ${path.module}/${var.vm_ssh_private_key_filename} ${var.vm_admin_username}@<VM_PRIVATE_IP>" : null
}
