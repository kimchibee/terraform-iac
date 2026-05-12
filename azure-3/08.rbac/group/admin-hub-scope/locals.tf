locals {
  enabled = var.admin_group_object_id != null && var.admin_group_scope_id != null && trimspace(var.admin_group_object_id) != "" && trimspace(var.admin_group_scope_id) != ""
}
