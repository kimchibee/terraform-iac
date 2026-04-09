terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
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

data "terraform_remote_state" "vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "azurerm_private_dns_zone" "zone" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = data.terraform_remote_state.vnet.outputs.hub_resource_group_name
}

module "link" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privatednszone/modules/private_dns_virtual_network_link?ref=main"

  name               = "hub-openai-to-hub-vnet"
  parent_id          = data.azurerm_private_dns_zone.zone.id
  virtual_network_id = data.terraform_remote_state.vnet.outputs.hub_vnet_id
}
