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

data "terraform_remote_state" "hub_vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

module "virtual_network_gateway" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-network-gateway?ref=chore/avm-vendoring-and-id-injection"

  name                 = "${var.project_name}-x-x-vpng"
  resource_group_id    = data.terraform_remote_state.hub_rg.outputs.resource_group_id
  virtual_network_id   = data.terraform_remote_state.hub_vnet.outputs.hub_vnet_id
  location             = var.location
  type                 = var.vpn_gateway_type
  vpn_type             = "RouteBased"
  sku                  = var.vpn_gateway_sku
  subnet_id            = data.terraform_remote_state.gateway_subnet.outputs.hub_subnet_id
  public_ip_address_id = data.terraform_remote_state.public_ip.outputs.public_ip_id
  tags                 = var.tags
}

output "virtual_network_gateway_id" {
  value = module.virtual_network_gateway.id
}
