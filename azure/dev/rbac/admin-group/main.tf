#--------------------------------------------------------------
# 관리자 그룹 — 구독 또는 리소스 그룹 범위 역할 할당
# rbac 루트에서 호출. provider는 azurerm.hub 전달.
#
# 역할 이름(role_definition_name)은 이 폴더 variables.tf 기본값에서 관리. 루트는 group_object_id, scope_id, member_object_ids 만 전달.
# [신규 그룹 추가 시] 폴더 복사 후 variables.tf에서 role_definition_name 등만 수정하고, 루트에 module 블록 + group/scope/member 변수만 추가.
#--------------------------------------------------------------

resource "azurerm_role_assignment" "this" {
  scope                = var.scope_id
  role_definition_name = var.role_definition_name
  principal_id         = var.group_object_id
}

#--------------------------------------------------------------
# admin-users: 그룹 멤버십 등록/변경/삭제 (Terraform 관리)
#--------------------------------------------------------------
module "admin_users" {
  source = "./admin-users"

  providers = {
    azuread = azuread
  }

  group_object_id   = var.group_object_id
  member_object_ids = var.member_object_ids
}
