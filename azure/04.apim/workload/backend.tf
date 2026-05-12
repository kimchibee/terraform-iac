#--------------------------------------------------------------
# Backend Configuration for API Management Stack
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # Backend 설정은 terraform init 시 -backend-config로 전달
    # key = "azure/dev/04.apim/workload/terraform.tfstate"
  }
}
