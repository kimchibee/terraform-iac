# 다른 스택은 **shared** 리프 state만 참조하면 Log Analytics·대시보드 출력을 한 번에 사용할 수 있음
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = data.terraform_remote_state.log_analytics.outputs.log_analytics_workspace_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = data.terraform_remote_state.log_analytics.outputs.log_analytics_workspace_name
  sensitive   = true
}

output "action_group_id" {
  description = "Removed legacy output (shared-services composite removed)"
  value       = null
}

output "dashboard_id" {
  description = "Removed legacy output (shared-services composite removed)"
  value       = null
}
