#--------------------------------------------------------------
# Linux VM 모듈 - Provider (루트에서 전달받음)
#--------------------------------------------------------------

terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
