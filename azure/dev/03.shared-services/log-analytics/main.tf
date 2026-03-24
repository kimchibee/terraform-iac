# Log Analytics Workspace standalone leaf
# (consumed by shared leaf via remote state)
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

locals {
  name_prefix    = "${var.project_name}-x-x"
  workspace_name = "${local.name_prefix}-${var.name_suffix}"
}

module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = { azurerm = azurerm.hub }

  name                = local.workspace_name
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
