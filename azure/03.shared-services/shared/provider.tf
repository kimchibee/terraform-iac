terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75, < 5.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id                 = var.hub_subscription_id
  resource_provider_registrations = "none"
  alias                           = "hub"
}

provider "azurerm" {
  features {}
  subscription_id                 = var.hub_subscription_id
  resource_provider_registrations = "none"
}
