data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "spoke_pep_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/subnet/spoke-pep-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "azurerm_resource_group" "spoke" {
  name = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_name
}

data "azurerm_private_dns_zone" "hub_openai" {
  provider            = azurerm.hub
  name                = "privatelink.openai.azure.com"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_azureml_api" {
  provider            = azurerm.hub
  name                = "privatelink.api.azureml.ms"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_notebooks" {
  provider            = azurerm.hub
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_client_config" "current" {}
