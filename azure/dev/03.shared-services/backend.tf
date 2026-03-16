#--------------------------------------------------------------
# Backend Configuration for Shared Services Stack
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # Backend 설정은 terraform init 시 -backend-config로 전달
    # key = "azure/dev/03.shared-services/terraform.tfstate"
  }
}
