#--------------------------------------------------------------
# Spoke — Azure Firewall Policy (+ 선택: Azure Firewall)
# Spoke 구독. 일반적으로 트래픽은 Hub 방화벽으로 보내고, Spoke 전용 방화벽이 필요할 때만 deploy_azure_firewall = true
#--------------------------------------------------------------
terraform {
  required_version = ">= 1.7.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}
