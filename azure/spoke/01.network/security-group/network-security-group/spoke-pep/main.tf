module "network_security_group" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-networksecuritygroup-main.git?ref=main"

  name                = local.nsg_name
  location            = var.location
  resource_group_name = data.terraform_remote_state.spoke_rg.outputs.resource_group_name
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
