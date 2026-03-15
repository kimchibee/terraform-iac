#--------------------------------------------------------------
# 관리자 그룹 — 구독 또는 리소스 그룹 범위 역할 할당
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
