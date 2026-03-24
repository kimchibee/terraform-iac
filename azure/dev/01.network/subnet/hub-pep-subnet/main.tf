#--------------------------------------------------------------
# Hub pep-snet (`hub-pep-subnet`)
# Single responsibility: create one pep-snet subnet
# Security rules/associations are managed by separate NSG/ASG/rule leaves
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
    key                  = "azure/dev/01.network/security-group/network-security-group/hub-pep/terraform.tfstate"
  }
}

locals {
  subnet_name = "pep-snet"
}

data "terraform_remote_state" "sg_hub_keyvault_clients_asg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/application-security-group/keyvault-clients/terraform.tfstate"
  }
}

data "terraform_remote_state" "sg_hub_vm_allowed_clients_asg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/application-security-group/vm-allowed-clients/terraform.tfstate"
  }
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/subnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.hub
  }

  name                              = local.subnet_name
  resource_group_name               = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
  virtual_network_name              = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  address_prefixes                  = ["10.0.4.0/24"]
  private_endpoint_network_policies = "Disabled"
  service_endpoints                 = ["Microsoft.Storage", "Microsoft.KeyVault"]
  network_security_group_id         = data.terraform_remote_state.hub_nsg.outputs.network_security_group_id
}
