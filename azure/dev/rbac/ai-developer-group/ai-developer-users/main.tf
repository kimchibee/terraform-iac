#--------------------------------------------------------------
# 그룹 멤버십 — 등록/변경/삭제 (Terraform 관리)
# member_object_ids에 있는 Object ID만 그룹 멤버로 유지.
# 목록에서 제거 후 apply 시 해당 멤버는 그룹에서 제거됨.
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
