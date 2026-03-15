#--------------------------------------------------------------
# Storage Stack (루트)
# monitoring-storage 는 하위 모듈로 호출
#--------------------------------------------------------------

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/compute/terraform.tfstate"
  }
}

locals {
  hub_key_vault_name = "${var.project_name}-hub-kv"
}

module "storage" {
  source = "./monitoring-storage"

  providers = {
    azurerm = azurerm.hub
  }

  project_name = var.project_name
  environment  = var.environment
  location      = var.location
  tags          = var.tags
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  key_vault_name      = local.hub_key_vault_name
  monitoring_vm_subnet_id = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  pep_subnet_id           = data.terraform_remote_state.network.outputs.hub_subnet_ids["pep-snet"]
  private_dns_zone_ids = data.terraform_remote_state.network.outputs.hub_private_dns_zone_ids
  enable_key_vault    = var.enable_key_vault
  monitoring_vm_identity_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, var.monitoring_vm_identity_principal_id)
  enable_monitoring_vm                 = var.enable_monitoring_vm
}
