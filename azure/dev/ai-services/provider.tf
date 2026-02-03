#--------------------------------------------------------------
# Provider Configuration for AI Services Stack
#--------------------------------------------------------------

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
}

# Spoke Subscription Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    cognitive_account {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
  alias                      = "spoke"
}

# Default provider (Spoke)
provider "azurerm" {
  features {}
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}
