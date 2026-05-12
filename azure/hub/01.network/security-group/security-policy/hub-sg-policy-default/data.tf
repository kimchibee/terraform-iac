#--------------------------------------------------------------
# Hub Azure Firewall Policy (+ optional Azure Firewall)
# Prerequisite: `vnet/hub-vnet` (AzureFirewallSubnet in same Hub RG)
# Route leaves can reference `hub_firewall_private_ip` output as next hop
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_firewall_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/subnet/hub-azurefirewall-subnet/terraform.tfstate"
  }
}

data "azurerm_resource_group" "hub" {
  name = local.hub_rg_name
}
