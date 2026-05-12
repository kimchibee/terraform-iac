data "terraform_remote_state" "spoke_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/spoke-rg/terraform.tfstate"
  }
}

data "azurerm_resource_group" "parent" {
  name = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
}
