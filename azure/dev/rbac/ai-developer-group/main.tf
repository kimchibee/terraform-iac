#--------------------------------------------------------------
# AI 개발자 그룹 — Spoke RG + OpenAI 역할 할당
# rbac 루트에서 호출. provider는 azurerm.spoke, azuread.
#
# Spoke RG 역할(spoke_rg_role_definition_name)은 이 폴더 variables.tf 기본값에서 관리. 루트는 group_object_id, spoke_resource_group_id, openai_id, member_object_ids 만 전달.
# [신규 그룹 추가 시] 폴더 복사 후 variables.tf에서 spoke_rg_role_definition_name 등만 수정하고, 루트에 module 블록 + 해당 그룹/scope/member 변수만 추가.
#--------------------------------------------------------------

resource "azurerm_role_assignment" "spoke_rg" {
  scope                = var.spoke_resource_group_id
  role_definition_name = var.spoke_rg_role_definition_name
  principal_id         = var.group_object_id
}

resource "azurerm_role_assignment" "openai_cognitive_services_user" {
  count = var.openai_id != null && trimspace(var.openai_id) != "" ? 1 : 0

  scope                = var.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.group_object_id
}

resource "azurerm_role_assignment" "openai_reader" {
  count = var.openai_id != null && trimspace(var.openai_id) != "" ? 1 : 0

  scope                = var.openai_id
  role_definition_name = "Reader"
  principal_id         = var.group_object_id
}

#--------------------------------------------------------------
# ai-developer-users: 그룹 멤버십 등록/변경/삭제 (Terraform 관리)
#--------------------------------------------------------------
module "ai_developer_users" {
  source = "./ai-developer-users"

  providers = {
    azuread = azuread
  }

  group_object_id   = var.group_object_id
  member_object_ids = var.member_object_ids
}
