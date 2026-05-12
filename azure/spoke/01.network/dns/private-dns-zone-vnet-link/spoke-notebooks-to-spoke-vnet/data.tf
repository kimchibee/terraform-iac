data "terraform_remote_state" "vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "azurerm_private_dns_zone" "zone" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = data.terraform_remote_state.vnet.outputs.spoke_resource_group_name
}
