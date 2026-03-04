#--------------------------------------------------------------
# Provider Configuration for Network Stack
#--------------------------------------------------------------

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.0"
    }
  }
}

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
    resource_group {
      # RG 삭제 시 내부 리소스(예: Azure 자동 생성 Action Group)가 있어도 Azure API로 RG 삭제 진행(연쇄 삭제)
      prevent_deletion_if_contains_resources = false
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
