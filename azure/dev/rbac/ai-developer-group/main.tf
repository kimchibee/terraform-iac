#--------------------------------------------------------------
# AI 개발자 그룹 — Spoke RG + OpenAI 역할 할당
# rbac 루트에서 호출. provider는 azurerm.spoke, azuread.
#
# [신규 AI/개발자용 그룹 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) ai-developer-group → data-scientist-group
# 2. 이 폴더 내부 수정:
#    - main.tf: 역할 이름/scope 필요 시 변경 (spoke_rg_role_definition_name, OpenAI 역할 등)
#    - variables.tf: spoke_resource_group_id, openai_id 등은 루트에서 전달. 변수 추가/삭제 시 루트와 맞출 것
#    - ai-developer-users 하위 폴더명 변경: 예) ai-developer-users → data-scientist-users, 모듈 source를 "./data-scientist-users"로
# 3. rbac 루트에서 수정할 것:
#    - main.tf: module "data_scientist_group" { source = "./data-scientist-group"; group_object_id = var.data_scientist_group_object_id; spoke_resource_group_id = data.terraform_remote_state.network.outputs.spoke_resource_group_id; openai_id = data.terraform_remote_state.ai_services.outputs.openai_id; member_object_ids = var.data_scientist_group_member_object_ids; ... } (count는 var로 활성화 여부 제어)
#    - variables.tf: data_scientist_group_object_id, data_scientist_group_member_object_ids 추가
#    - terraform.tfvars: 그룹 Object ID, 멤버 Object ID 목록 설정
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
