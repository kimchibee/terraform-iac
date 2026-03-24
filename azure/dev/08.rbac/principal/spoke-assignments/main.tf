#--------------------------------------------------------------
# 워크로드 주체 — Spoke 구독 역할 할당 (Monitoring VM MI)
#--------------------------------------------------------------

data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/06.compute/linux-monitoring-vm/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "ai_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/05.ai-services/workload/terraform.tfstate"
  }
}

locals {
  vm_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, null)
  enable_roles    = var.enable_monitoring_vm_roles && local.vm_principal_id != null
}

resource "azurerm_role_assignment" "vm_spoke_key_vault_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.key_vault_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.ai_services.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_storage_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.storage_account_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.ai_services.outputs.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_reader" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_rg_reader" {
  count = local.enable_roles ? 1 : 0

  scope                = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}
