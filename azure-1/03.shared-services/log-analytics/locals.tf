locals {
  name_prefix    = "${var.project_name}-x-x"
  workspace_name = "${local.name_prefix}-${var.name_suffix}"
}
