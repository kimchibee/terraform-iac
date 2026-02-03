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
