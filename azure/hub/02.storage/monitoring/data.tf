data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_pep_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfstate"
  }
}

data "azurerm_private_dns_zone" "hub_blob_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_vault_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
}

data "terraform_remote_state" "compute" {
  count   = local.use_compute_remote_state ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/06.compute/linux-monitoring-vm/terraform.tfstate"
  }
}

data "azurerm_client_config" "current" {}
