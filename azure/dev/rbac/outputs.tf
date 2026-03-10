#--------------------------------------------------------------
# RBAC Stack Outputs (필요 시 다른 스택에서 참조)
#--------------------------------------------------------------

output "monitoring_vm_roles_enabled" {
  description = "Monitoring VM에 역할 부여가 활성화되었는지"
  value       = local.enable_roles
}
