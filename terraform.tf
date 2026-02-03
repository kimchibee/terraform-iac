#--------------------------------------------------------------
# Terraform Settings
# Backend 설정, required providers, 최소 Terraform 버전 등을 선언
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

  # Backend 설정 예시 (필요시 주석 해제하여 사용)
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "terraformstate"
  #   container_name       = "tfstate"
  #   key                  = "terraform.tfstate"
  # }
}
