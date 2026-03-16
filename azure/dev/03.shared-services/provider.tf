#--------------------------------------------------------------
# Provider Configuration for Shared Services Stack
#--------------------------------------------------------------

# log_analytics_workspace 모듈(terraform-modules AVM 래퍼)이 Terraform 1.9+ 요구
terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.75, < 5.0"
    }
  }
}

# Hub Subscription Provider
# resource_provider_registrations: "none" | "legacy" | "core" | "extended" | "all"
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

# Default provider (Hub)
provider "azurerm" {
  features {}
  subscription_id                 = var.hub_subscription_id
  resource_provider_registrations = "none"
}
