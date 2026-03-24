#--------------------------------------------------------------
# 관리자 그룹 — Hub 구독 범위 역할 할당 (기존 admin-group 의 azurerm_role_assignment)
#--------------------------------------------------------------

locals {
  enabled = var.admin_group_object_id != null && var.admin_group_scope_id != null && trimspace(var.admin_group_object_id) != "" && trimspace(var.admin_group_scope_id) != ""
}

resource "azurerm_role_assignment" "this" {
  count = local.enabled ? 1 : 0

  scope                = var.admin_group_scope_id
  role_definition_name = var.role_definition_name
  principal_id         = var.admin_group_object_id
}
