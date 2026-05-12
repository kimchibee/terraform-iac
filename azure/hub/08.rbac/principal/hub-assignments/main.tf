#--------------------------------------------------------------
# 워크로드 주체(Managed Identity) — Hub 구독 역할 할당 (Monitoring VM MI 등)
#--------------------------------------------------------------


resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = local.enable_roles && length(try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {})) > 0 ? try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {}) : {}

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Reader"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_hub_rg_reader" {
  count = local.enable_roles ? 1 : 0

  scope                = data.terraform_remote_state.network.outputs.hub_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}
