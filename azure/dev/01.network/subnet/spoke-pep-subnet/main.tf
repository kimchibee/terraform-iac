#--------------------------------------------------------------
# Spoke pep-snet (`spoke-pep-subnet`)
# Single responsibility: create one pep-snet subnet
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

data "terraform_remote_state" "spoke_nsg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/network-security-group/spoke-pep/terraform.tfstate"
  }
}

locals {
  subnet_name = "pep-snet"
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.spoke
  name                = data.terraform_remote_state.vnet_spoke.outputs.spoke_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                              = local.subnet_name
  parent_id                         = data.azurerm_virtual_network.parent.id
  address_prefixes                  = ["10.1.0.64/26"]
  private_endpoint_network_policies = "Disabled"
  network_security_group = {
    id = data.terraform_remote_state.spoke_nsg.outputs.network_security_group_id
  }
}
