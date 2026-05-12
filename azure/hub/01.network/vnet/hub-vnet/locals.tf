locals {
  name_prefix   = "${var.project_name}-x-x"
  hub_vnet_name = "${local.name_prefix}-vnet"
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}
