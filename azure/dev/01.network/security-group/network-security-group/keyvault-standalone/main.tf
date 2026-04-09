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

locals {
  nsg_security_rules = [
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

module "network_security_group" {
  count  = var.enabled ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-networksecuritygroup?ref=main"

  name                = local.nsg_name
  location            = data.terraform_remote_state.hub_rg.outputs.location
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  tags                = var.tags
  enable_telemetry    = false
  security_rules = {
    for rule in local.nsg_security_rules : rule.name => {
      name                                       = rule.name
      priority                                   = rule.priority
      direction                                  = rule.direction
      access                                     = rule.access
      protocol                                   = rule.protocol
      source_port_range                          = try(rule.source_port_range, null)
      source_port_ranges                         = try(rule.source_port_ranges, null)
      destination_port_range                     = try(rule.destination_port_range, null)
      destination_port_ranges                    = try(rule.destination_port_ranges, null)
      source_address_prefix                      = try(rule.source_address_prefix, null)
      source_address_prefixes                    = try(rule.source_address_prefixes, null)
      destination_address_prefix                 = try(rule.destination_address_prefix, null)
      destination_address_prefixes               = try(rule.destination_address_prefixes, null)
      source_application_security_group_ids      = try(toset(rule.source_application_security_group_ids), null)
      destination_application_security_group_ids = try(toset(rule.destination_application_security_group_ids), null)
      description                                = try(rule.description, null)
    }
  }
}
