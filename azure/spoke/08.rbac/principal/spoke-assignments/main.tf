#--------------------------------------------------------------
# 워크로드 주체 — Spoke 구독 역할 할당 (Monitoring VM MI)
#--------------------------------------------------------------


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
