#--------------------------------------------------------------
# Compute 루트 Backend (State 1개)
# key: azure/dev/compute/terraform.tfstate
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # init 시 -backend-config=backend.hcl
  }
}
