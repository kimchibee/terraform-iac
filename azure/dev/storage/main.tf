#--------------------------------------------------------------
# Storage Stack
# Key Vault와 Monitoring Storage Accounts를 관리하는 스택
# AWS 방식: network 스택의 remote_state를 읽어서 의존성 해결
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Stack Remote State
# network 스택의 출력을 읽어서 사용
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

#--------------------------------------------------------------
# Compute Stack Remote State (Optional)
# Monitoring VM Identity를 읽기 위해 사용
# compute 스택이 배포되지 않았으면 빈 문자열 사용
#--------------------------------------------------------------
data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/compute/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Storage Module (Key Vault & Monitoring Storage)
#--------------------------------------------------------------
module "storage" {
  source = "../../../modules/dev/hub/monitoring-storage"

  providers = {
    azurerm = azurerm.hub
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group (from network stack)
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  key_vault_name      = local.hub_key_vault_name

  # Subnet IDs (from network stack)
  monitoring_vm_subnet_id = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  pep_subnet_id           = data.terraform_remote_state.network.outputs.hub_subnet_ids["pep-snet"]

  # Private DNS Zones (from network stack)
  private_dns_zone_ids = data.terraform_remote_state.network.outputs.hub_private_dns_zone_ids

  # Feature Flags
  enable_key_vault = var.enable_key_vault

  # Monitoring VM Identity (compute 스택에서 remote_state로 받음)
  # compute 스택이 배포되지 않았으면 빈 문자열 사용
  monitoring_vm_identity_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, var.monitoring_vm_identity_principal_id)
  enable_monitoring_vm                 = var.enable_monitoring_vm
}
