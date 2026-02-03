#--------------------------------------------------------------
# Shared Services Stack Outputs
# 다른 스택에서 terraform_remote_state로 참조
#--------------------------------------------------------------

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.log_analytics_workspace.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = module.log_analytics_workspace.name
}

output "action_group_id" {
  description = "Action Group ID"
  value       = module.shared_services.action_group_id
}

output "dashboard_id" {
  description = "Dashboard ID"
  value       = module.shared_services.dashboard_id
}
