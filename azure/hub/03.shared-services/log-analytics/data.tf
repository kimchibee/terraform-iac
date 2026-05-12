# Log Analytics Workspace standalone leaf
# (consumed by shared leaf via remote state)
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}
