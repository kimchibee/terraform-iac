#--------------------------------------------------------------
# AI 개발자 그룹 — Spoke RG + OpenAI 역할 (기존 ai-developer-group)
#--------------------------------------------------------------


resource "azurerm_role_assignment" "spoke_rg" {
  count = local.enabled ? 1 : 0

  scope                = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_id
  role_definition_name = var.spoke_rg_role_definition_name
  principal_id         = var.ai_developer_group_object_id
}

resource "azurerm_role_assignment" "openai_cognitive_services_user" {
  count = local.enabled && local.openai_id != null && trimspace(local.openai_id) != "" ? 1 : 0

  scope                = local.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.ai_developer_group_object_id
}

resource "azurerm_role_assignment" "openai_reader" {
  count = local.enabled && local.openai_id != null && trimspace(local.openai_id) != "" ? 1 : 0

  scope                = local.openai_id
  role_definition_name = "Reader"
  principal_id         = var.ai_developer_group_object_id
}
