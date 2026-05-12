locals {
  name_prefix               = "${var.project_name}-x-x"
  spoke_resource_group_name = "${local.name_prefix}-spoke-rg"
}
