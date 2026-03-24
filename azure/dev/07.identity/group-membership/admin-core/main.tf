#--------------------------------------------------------------
# Entra ID 그룹 멤버십 — 관리자 그룹 (기존 단일 rbac 스택의 admin-users)
#--------------------------------------------------------------

locals {
  member_ids = toset([
    for id in var.member_object_ids :
    id if id != null && trimspace(id) != ""
  ])
}

resource "azuread_group_member" "this" {
  for_each = local.member_ids

  group_object_id  = var.group_object_id
  member_object_id = each.value
}
