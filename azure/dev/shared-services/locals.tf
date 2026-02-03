#--------------------------------------------------------------
# Shared Services Stack Local Values
#--------------------------------------------------------------

locals {
  name_prefix           = "${var.project_name}-x-x"
  hub_log_analytics_name = "${local.name_prefix}-law"
}
