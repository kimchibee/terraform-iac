terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

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
  features {}
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}


module "zone" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privatednszone?ref=main"

  domain_name      = "privatelink.azure-api.net"
  parent_id        = data.azurerm_resource_group.parent.id
  tags             = var.tags
  enable_telemetry = false
}

output "private_dns_zone_id" {
  value = module.zone.resource_id
}
