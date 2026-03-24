#--------------------------------------------------------------
# Hub — Azure Firewall Policy + Firewall (vnet/hub-vnet 이후, AzureFirewallSubnet 필요)
#--------------------------------------------------------------
terraform {
  # AVM(Firewall Policy / Azure Firewall) 서브모듈: ~> 1.5 / ~> 1.7 요구 — 최소 1.7 로 통일
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
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

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}
