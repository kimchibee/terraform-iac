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

module "public_ip" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/public-ip?ref=chore/avm-vendoring-and-id-injection"

  name                = "${var.project_name}-x-x-vpng-pip"
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location            = var.location
  tags                = var.tags
}

output "public_ip_id" {
  value = module.public_ip.id
}

output "public_ip_address" {
  value = module.public_ip.ip_address
}
