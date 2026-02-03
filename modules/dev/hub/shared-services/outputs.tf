output "action_group_id" {
  description = "Action Group ID"
  value       = var.enable ? azurerm_monitor_action_group.main[0].id : null
}

output "dashboard_id" {
  description = "Dashboard ID"
  value       = var.enable ? azurerm_portal_dashboard.main[0].id : null
}
