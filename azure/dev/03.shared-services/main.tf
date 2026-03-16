#--------------------------------------------------------------
# Shared Services Stack (루트)
# log-analytics-workspace, shared-services 는 하위 모듈로 호출
#--------------------------------------------------------------

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-x-x"
}

module "log_analytics_workspace" {
  source = "./log-analytics-workspace"
  providers = { azurerm = azurerm.hub }
  name_prefix         = local.name_prefix
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  tags                = var.tags
}

module "shared_services" {
  source = "./shared-services"
  providers = { azurerm = azurerm.hub }
  resource_group_name         = data.terraform_remote_state.network.outputs.hub_resource_group_name
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_workspace_name = module.log_analytics_workspace.name
  project_name                 = var.project_name
  location                     = var.location
  tags                         = var.tags
}
