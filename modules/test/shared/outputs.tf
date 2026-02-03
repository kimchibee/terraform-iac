#--------------------------------------------------------------
# Log Analytics Outputs
#--------------------------------------------------------------
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_primary_key" {
  description = "Log Analytics Workspace primary key"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "log_analytics_workspace_workspace_id" {
  description = "Log Analytics Workspace workspace ID (GUID)"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

#--------------------------------------------------------------
# Action Group Outputs
#--------------------------------------------------------------
output "action_group_id" {
  description = "Action Group ID"
  value       = var.enable_shared_services ? azurerm_monitor_action_group.main[0].id : null
}

#--------------------------------------------------------------
# Dashboard Outputs
#--------------------------------------------------------------
output "dashboard_id" {
  description = "Dashboard ID"
  value       = var.enable_shared_services ? azurerm_portal_dashboard.main[0].id : null
}
