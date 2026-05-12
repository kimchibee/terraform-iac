#--------------------------------------------------------------
# Backend — Spoke VNet 리프 전용 state
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    # key = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}
