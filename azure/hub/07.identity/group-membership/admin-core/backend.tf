#--------------------------------------------------------------
# Backend — state 키는 generate-backend-hcl.sh 가 디렉터리 경로와 동일하게 생성
# key = azure/dev/07.identity/group-membership/admin-core/terraform.tfstate
#--------------------------------------------------------------
terraform {
  backend "azurerm" {}
}
