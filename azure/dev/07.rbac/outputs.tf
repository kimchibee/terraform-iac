#--------------------------------------------------------------
# RBAC Stack Outputs (필요 시 다른 스택에서 참조)
#--------------------------------------------------------------

output "monitoring_vm_roles_enabled" {
  description = "Monitoring VM에 역할 부여가 활성화되었는지"
  value       = local.enable_roles
}

# 시나리오 1: 그룹 기반 권한 (폴더 단위 모듈)
output "admin_group_role_assignment_id" {
  description = "관리자 그룹 역할 할당 ID (설정 시)"
  value       = try(module.admin_group[0].role_assignment_id, null)
}

output "ai_developer_group_roles_enabled" {
  description = "AI 개발자 그룹 역할 부여가 활성화되었는지"
  value       = local.enable_ai_developer_group
}
