#--------------------------------------------------------------
# Backend Configuration for AI Services Stack
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # Backend 설정은 terraform init 시 -backend-config로 전달
    # key = "azure/dev/05.ai-services/workload/terraform.tfstate"
  }
}
