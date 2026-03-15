#--------------------------------------------------------------
# vm-access-sg 모듈 provider
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
