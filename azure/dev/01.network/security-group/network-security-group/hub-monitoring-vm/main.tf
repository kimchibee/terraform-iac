terraform {
  required_version = ">= 1.9.0, < 2.0"

  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}

provider "azapi" {
  subscription_id = var.hub_subscription_id
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

data "terraform_remote_state" "vm_allowed_clients" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/security-group/application-security-group/vm-allowed-clients/terraform.tfstate"
  }
}

locals {
  nsg_name = "${var.project_name}-x-x-monitoring-vm-nsg"
}

module "network_security_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/network-security-group?ref=chore/avm-vendoring-and-id-injection"

  name                = local.nsg_name
  location            = var.location
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  tags                = var.tags
  security_rules = [
    {
      name                                  = "AllowVMClients-22"
      priority                              = 4090
      direction                             = "Inbound"
      access                                = "Allow"
      protocol                              = "Tcp"
      source_port_range                     = "*"
      destination_port_range                = "22"
      source_application_security_group_ids = [data.terraform_remote_state.vm_allowed_clients.outputs.vm_allowed_clients_asg_id]
      destination_address_prefix            = "*"
    },
    {
      name                                  = "AllowVMClients-3389"
      priority                              = 4091
      direction                             = "Inbound"
      access                                = "Allow"
      protocol                              = "Tcp"
      source_port_range                     = "*"
      destination_port_range                = "3389"
      source_application_security_group_ids = [data.terraform_remote_state.vm_allowed_clients.outputs.vm_allowed_clients_asg_id]
      destination_address_prefix            = "*"
    },
    {
      name                       = "AllowKeyVaultOutbound"
      priority                   = 4096
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureKeyVault"
    }
  ]
}

output "network_security_group_id" {
  value = module.network_security_group.id
}

output "network_security_group_name" {
  value = module.network_security_group.name
}
