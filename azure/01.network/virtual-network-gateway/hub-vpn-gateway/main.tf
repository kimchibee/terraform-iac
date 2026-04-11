terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.116.0, < 5.0.0"
    }
  }
}

variable "project_name" { type = string }
variable "location" { type = string }
variable "tags" {
  type = map(string)
  default = {}
}
variable "hub_subscription_id" { type = string }
variable "backend_resource_group_name" { type = string }
variable "backend_storage_account_name" { type = string }
variable "backend_container_name" {
  type    = string
  default = "tfstate"
}
variable "vpn_gateway_sku" {
  type    = string
  default = "VpnGw1"
}

variable "vpn_gateway_type" {
  type    = string
  default = "Vpn"
}

provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}


module "virtual_network_gateway" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-ptn-vnetgateway?ref=main"

  parent_id = data.azurerm_resource_group.parent.id
  name      = "${var.project_name}-x-x-vpng"
  location  = var.location
  tags      = var.tags

  virtual_network_id                = local.virtual_network_id
  virtual_network_gateway_subnet_id = local.gateway_subnet_id

  vpn_type                  = "RouteBased"
  vpn_generation            = "Generation1"
  vpn_active_active_enabled = false
  vpn_bgp_enabled           = false

  enable_telemetry = false
}

output "virtual_network_gateway_id" {
  value = module.virtual_network_gateway.resource_id
}
