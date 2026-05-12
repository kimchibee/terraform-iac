output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.log_analytics_workspace.resource_id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = module.log_analytics_workspace.resource.name
  sensitive   = true
}
