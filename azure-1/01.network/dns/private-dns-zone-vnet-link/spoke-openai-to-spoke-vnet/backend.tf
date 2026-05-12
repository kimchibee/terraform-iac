#--------------------------------------------------------------
# Backend Configuration
#--------------------------------------------------------------
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatea9911"
    container_name       = "tfstate"
    key                  = "01.network/dns/private-dns-zone-vnet-link/spoke-openai-to-spoke-vnet/terraform.tfstate"
  }
}
