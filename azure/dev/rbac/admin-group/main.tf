#--------------------------------------------------------------
# 관리자 그룹 — 구독 또는 리소스 그룹 범위 역할 할당
# rbac 루트에서 호출. provider는 azurerm.hub 전달.
#
# [신규 그룹(예: 서비스 관리자 그룹) 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) admin-group → service-admin-group
# 2. 이 폴더 내부 수정:
#    - variables.tf: description 등 필요 시 수정. 변수명(group_object_id, scope_id, role_definition_name, member_object_ids)은 루트에서 다른 이름으로 전달 가능
#    - admin-users 하위 폴더명을 서비스 관리자용으로 변경: 예) admin-users → service-admin-users (그리고 해당 모듈 source를 "./service-admin-users"로)
# 3. rbac 루트에서 수정할 것:
#    - main.tf: module "service_admin_group" { source = "./service-admin-group"; group_object_id = var.service_admin_group_object_id; scope_id = var.service_admin_group_scope_id; role_definition_name = var.service_admin_group_role_definition_name; member_object_ids = var.service_admin_group_member_object_ids; providers = { azurerm = azurerm.hub; azuread = azuread } } (count는 var로 활성화 여부 제어)
#    - variables.tf: service_admin_group_object_id, service_admin_group_scope_id, service_admin_group_role_definition_name, service_admin_group_member_object_ids 추가
#    - terraform.tfvars: Azure AD 그룹 Object ID, scope(구독 또는 RG ID), 역할 이름, 멤버 Object ID 목록 설정
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
