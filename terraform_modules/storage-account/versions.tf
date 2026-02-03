#-------------------------------------------------------------------------------
# Storage Account 모듈 - Provider 요구 사항
# 호출 측(terraform-infra)에서 azurerm, random provider 설정
#-------------------------------------------------------------------------------
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
