#--------------------------------------------------------------
# Hub Monitoring-VM-Subnet (`hub-monitoring-vm-subnet`)
# Single responsibility: create one Monitoring-VM-Subnet
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

data "terraform_remote_state" "hub_nsg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/network-security-group/hub-monitoring-vm/terraform.tfstate"
  }
}

locals {
  subnet_name = "Monitoring-VM-Subnet"
}

data "azurerm_virtual_network" "parent" {
  provider            = azurerm.hub
  name                = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  resource_group_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}

locals {
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name             = local.subnet_name
  parent_id        = data.azurerm_virtual_network.parent.id
  address_prefixes = ["10.0.1.0/24"]
  service_endpoints_with_location = [
    for service in local.service_endpoints : {
      service   = service
      locations = ["*"]
    }
  ]
  network_security_group = {
    id = data.terraform_remote_state.hub_nsg.outputs.network_security_group_id
  }
}
