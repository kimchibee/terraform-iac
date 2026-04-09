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
variable "hub_subscription_id" { type = string }
variable "backend_resource_group_name" { type = string }
variable "backend_storage_account_name" { type = string }
variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
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

data "azurerm_resource_group" "parent" {
  name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
}

module "zone" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privatednszone?ref=main"

  domain_name      = "privatelink.blob.core.windows.net"
  parent_id        = data.azurerm_resource_group.parent.id
  tags             = var.tags
  enable_telemetry = false
}

output "private_dns_zone_id" {
  value = module.zone.resource_id
}
