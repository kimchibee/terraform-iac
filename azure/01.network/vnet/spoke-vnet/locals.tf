locals {
  name_prefix     = "${var.project_name}-x-x"
  spoke_vnet_name = "${local.name_prefix}-${var.vnet_suffix}"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}
