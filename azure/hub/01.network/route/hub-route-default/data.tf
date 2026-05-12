# Hub UDR leaf: creates route table, optionally associates Monitoring-VM-Subnet,
# and manages custom/auto routes for Spoke traffic.
# Route table is provisioned via shared AVM wrapper module.
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "vnet_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.spoke_backend_resource_group_name
    storage_account_name = var.spoke_backend_storage_account_name
    container_name       = var.spoke_backend_container_name
    key                  = "azure/dev/spoke/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_security_policy" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/security-group/security-policy/hub-sg-policy-default/terraform.tfstate"
  }
}
