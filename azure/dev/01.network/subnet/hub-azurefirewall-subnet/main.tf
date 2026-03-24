#--------------------------------------------------------------
# Hub AzureFirewallSubnet (`hub-azurefirewall-subnet`)
# Single responsibility: create one AzureFirewallSubnet
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

locals {
  subnet_name = "AzureFirewallSubnet"
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/subnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.hub
  }

  name                 = local.subnet_name
  resource_group_name  = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
  virtual_network_name = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  address_prefixes     = ["10.0.2.0/26"]
}
