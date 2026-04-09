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
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/subnet?ref=chore/avm-vendoring-and-id-injection"

  providers = {
    azurerm = azurerm.spoke
  }

  name               = local.subnet_name
  virtual_network_id = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_id
  address_prefixes   = ["10.1.0.0/26"]
  service_endpoints  = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
}
