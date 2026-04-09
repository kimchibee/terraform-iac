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

data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}

data "terraform_remote_state" "gateway_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-gateway-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "public_ip" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/public-ip/hub-vpn-gateway/terraform.tfstate"
  }
}

data "azurerm_resource_group" "parent" {
  name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
}

locals {
  gateway_subnet_id  = data.terraform_remote_state.gateway_subnet.outputs.hub_subnet_id
  virtual_network_id = regex("(?i)(.*/virtualNetworks/[^/]+)/subnets/[^/]+", local.gateway_subnet_id)[0]
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
