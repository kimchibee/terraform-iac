#--------------------------------------------------------------
# RBAC Stack
# Monitoring VM(compute 스택) Managed Identity에 Hub/Spoke 리소스 접근 역할만 부여
# compute → rbac 순서로 적용 (VM 생성 후 역할 부여)
#--------------------------------------------------------------

#--------------------------------------------------------------
# Remote State: Compute (VM identity), Network, Storage, AI Services
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

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/storage/terraform.tfstate"
  }
}

data "terraform_remote_state" "ai_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/ai-services/terraform.tfstate"
  }
}

locals {
  vm_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, null)
  enable_roles    = var.enable_monitoring_vm_roles && local.vm_principal_id != null
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Storage Accounts (Blob Data Contributor)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = local.enable_roles && length(try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {})) > 0 ? try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {}) : {}

  provider = azurerm.hub

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Key Vault (Secrets User, Reader)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Reader"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Hub Resource Group (Reader)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_reader" {
  count = local.enable_roles ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.network.outputs.hub_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Spoke: Monitoring VM → Spoke Key Vault, Storage, OpenAI, RG
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_spoke_key_vault_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_storage_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.storage_account_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_reader" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_reader" {
  count = local.enable_roles ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.network.outputs.spoke_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}
