terraform {
  required_version = ">= 1.9.0, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

variable "project_name" { type = string }
variable "location" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}
variable "spoke_subscription_id" { type = string }
variable "backend_resource_group_name" { type = string }
variable "backend_storage_account_name" { type = string }
variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}

provider "azapi" {
  subscription_id = var.spoke_subscription_id
}


module "network_security_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-networksecuritygroup?ref=main"

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

output "network_security_group_id" {
  value = module.network_security_group.resource_id
}

output "network_security_group_name" {
  value = module.network_security_group.name
}
