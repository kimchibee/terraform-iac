#--------------------------------------------------------------
# Spoke apim-snet (`spoke-apim-subnet`)
# Single responsibility: create one apim-snet subnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.spoke
  name                = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
}
