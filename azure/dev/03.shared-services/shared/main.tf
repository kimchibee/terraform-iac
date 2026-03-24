data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "log_analytics" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/03.shared-services/log-analytics/terraform.tfstate"
  }
}

# shared-services composite 모듈 제거 후,
# shared 리프는 log-analytics 집계/중계 역할만 수행한다.
locals {
  shared_leaf_enabled = var.enable
}
