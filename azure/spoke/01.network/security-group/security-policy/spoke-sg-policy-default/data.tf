#--------------------------------------------------------------
# Spoke Azure Firewall Policy (+ optional Azure Firewall)
# Prerequisite: `vnet/spoke-vnet` (requires firewall subnet id when firewall is enabled)
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "azurerm_resource_group" "spoke" {
  name = local.spoke_rg_name
}
