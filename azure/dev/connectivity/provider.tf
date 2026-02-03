#--------------------------------------------------------------
# Provider Configuration for Connectivity Stack
#--------------------------------------------------------------

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

# Hub Subscription Provider
provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
  alias                      = "hub"
}

# Default provider (Hub)
provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}
