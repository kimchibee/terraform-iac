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

# spoke-openai zone (spoke 구독에 위치)을 hub VNet에 link한다.
# remote_state로 zone ID를 cross-subscription read.
data "terraform_remote_state" "zone" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/dns/private-dns-zone/spoke-openai/terraform.tfstate"
  }
}

module "link" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-dns-zone-vnet-link?ref=chore/avm-vendoring-and-id-injection"

  name                = "hub-openai-to-hub-vnet"
  private_dns_zone_id = data.terraform_remote_state.zone.outputs.private_dns_zone_id
  virtual_network_id  = data.terraform_remote_state.vnet.outputs.hub_vnet_id
}
