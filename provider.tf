#--------------------------------------------------------------
# Provider Configuration
# Provider 및 region, default tags 등을 설정
#--------------------------------------------------------------

# Hub Subscription Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
  alias                      = "hub"
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

# Default provider (Hub)
provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}

provider "azapi" {
  subscription_id = var.hub_subscription_id
}
