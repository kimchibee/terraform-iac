terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.36"
    }
  }
}

variable "project_name" { type = string }
variable "location" { type = string }
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

data "terraform_remote_state" "hub_vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_dns_inbound_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-dnsresolver-inbound-subnet/terraform.tfstate"
  }
}

module "dns_private_resolver" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-dnsresolver?ref=main"

  name                        = "${var.project_name}-x-x-pdr"
  resource_group_name         = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location                    = var.location
  virtual_network_resource_id = data.terraform_remote_state.hub_vnet.outputs.hub_vnet_id
  tags                        = var.tags
  enable_telemetry            = false
  inbound_endpoints = {
    hub = {
      name        = "hub-dns-inbound"
      subnet_name = data.terraform_remote_state.hub_dns_inbound_subnet.outputs.hub_subnet_name
    }
  }
}

output "dns_private_resolver_id" {
  value = module.dns_private_resolver.resource_id
}

output "dns_private_resolver_inbound_endpoint_ids" {
  value = { for k, v in module.dns_private_resolver.inbound_endpoints : k => v.id }
}

output "dns_private_resolver_inbound_endpoint_ip_addresses" {
  value = module.dns_private_resolver.inbound_endpoint_ips
}
