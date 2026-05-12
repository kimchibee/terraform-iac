data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_subnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/subnet/hub-pep-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}
