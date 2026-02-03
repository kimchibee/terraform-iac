#--------------------------------------------------------------
# Backend Configuration for Storage Stack
# 각 스택은 독립적인 State 파일을 가짐
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # Backend 설정은 terraform init 시 -backend-config로 전달하거나
    # 환경 변수로 설정 가능
    # resource_group_name  = "terraform-state-rg"
    # storage_account_name = "terraformstate"
    # container_name       = "tfstate"
    # key                  = "azure/dev/storage/terraform.tfstate"
    # use_azuread_auth     = false
  }
}
