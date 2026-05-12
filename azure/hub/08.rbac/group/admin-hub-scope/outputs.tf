output "role_assignment_id" {
  description = "역할 할당 ID"
  value       = try(azurerm_role_assignment.this[0].id, null)
}
