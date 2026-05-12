data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/06.compute/linux-monitoring-vm/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "ai_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/05.ai-services/workload/terraform.tfstate"
  }
}
