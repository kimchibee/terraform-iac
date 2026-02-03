#--------------------------------------------------------------
# Shared Services Stack
# Log Analytics Workspace와 Shared Services를 관리하는 스택
# AWS 방식: network 스택의 remote_state를 읽어서 의존성 해결
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Stack Remote State
# network 스택의 출력을 읽어서 사용
#--------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Log Analytics Workspace (공통 모듈)
#--------------------------------------------------------------
module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_log_analytics_name
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

#--------------------------------------------------------------
# Shared Services: Solutions / Action Group / Dashboard (IaC 모듈)
#--------------------------------------------------------------
module "shared_services" {
  source = "../../../modules/dev/hub/shared-services"

  providers = {
    azurerm = azurerm.hub
  }

  enable                      = var.enable_shared_services
  resource_group_name         = data.terraform_remote_state.network.outputs.hub_resource_group_name
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_workspace_name = module.log_analytics_workspace.name
  project_name                 = var.project_name
  location                     = var.location
  tags                         = var.tags
}
