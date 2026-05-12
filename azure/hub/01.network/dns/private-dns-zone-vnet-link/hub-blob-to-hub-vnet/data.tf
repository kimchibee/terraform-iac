data "terraform_remote_state" "zone" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/dns/private-dns-zone/hub-blob/terraform.tfstate"
  }
}

data "terraform_remote_state" "vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "azurerm_private_dns_zone" "zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.terraform_remote_state.vnet.outputs.hub_resource_group_name
}
