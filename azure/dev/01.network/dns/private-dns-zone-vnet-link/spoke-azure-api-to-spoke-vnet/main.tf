terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
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

data "terraform_remote_state" "vnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

module "link" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-dns-zone-vnet-link?ref=chore/avm-wave1-modules-prune-and-convert"

  name                  = "spoke-azure-api-to-spoke-vnet"
  resource_group_name   = data.terraform_remote_state.vnet.outputs.spoke_resource_group_name
  private_dns_zone_name = "privatelink.azure-api.net"
  virtual_network_id    = data.terraform_remote_state.vnet.outputs.spoke_vnet_id
}
