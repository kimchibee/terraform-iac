#--------------------------------------------------------------
# Legacy local shim.
# New shared-service leaves should call the Git shared module directly.
# This wrapper remains only for compatibility while older refs are cleaned up.
#--------------------------------------------------------------
locals {
  name = "${var.name_prefix}-${var.name_suffix}"
}

module "log_analytics_workspace" {
  source              = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=chore/avm-vendoring-and-id-injection"
  providers           = { azurerm = azurerm }
  name                = local.name
  location            = var.location
  resource_group_name = var.resource_group_name
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
