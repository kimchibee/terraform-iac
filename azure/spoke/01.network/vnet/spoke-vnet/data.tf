# Spoke VNet 리프
# Single responsibility: provision Spoke Virtual Network only
data "terraform_remote_state" "spoke_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/resource-group/spoke-rg/terraform.tfstate"
  }
}
