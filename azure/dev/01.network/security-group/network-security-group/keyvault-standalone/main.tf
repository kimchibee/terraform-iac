locals {
  name_prefix = "${var.project_name}-x-x"
  nsg_name    = var.nsg_name != "" ? var.nsg_name : "${local.name_prefix}-keyvault-sg"
}

data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}

module "network_security_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/network-security-group?ref=chore/avm-wave1-modules-prune-and-convert"

  enabled             = var.enabled
  name                = local.nsg_name
  location            = data.terraform_remote_state.hub_rg.outputs.location
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  tags                = var.tags
  security_rules = [
    {
      name                       = "AllowKeyVaultOutbound"
      priority                   = 4096
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureKeyVault"
    }
  ]
}
