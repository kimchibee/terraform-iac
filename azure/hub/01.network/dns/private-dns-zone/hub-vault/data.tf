data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}

data "azurerm_resource_group" "parent" {
  name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
}
