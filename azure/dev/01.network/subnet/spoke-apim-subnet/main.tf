#--------------------------------------------------------------
# Spoke apim-snet (`spoke-apim-subnet`)
# Single responsibility: create one apim-snet subnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

locals {
  subnet_name = "apim-snet"
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/subnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  name                 = local.subnet_name
  resource_group_name  = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
  virtual_network_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_name
  address_prefixes     = ["10.1.0.0/26"]
  service_endpoints    = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
}
