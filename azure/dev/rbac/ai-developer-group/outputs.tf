output "spoke_rg_role_assignment_id" {
  description = "Spoke RG 역할 할당 ID"
  value       = azurerm_role_assignment.spoke_rg.id
}

output "openai_roles_enabled" {
  description = "OpenAI 리소스에 역할 부여 여부"
  value       = var.openai_id != null && trimspace(var.openai_id) != ""
}
