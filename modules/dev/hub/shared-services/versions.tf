#--------------------------------------------------------------
# Shared Services 모듈 - Provider 선언 (validate 경고 제거)
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0"
    }
  }
}
