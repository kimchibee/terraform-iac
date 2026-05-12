#--------------------------------------------------------------
# Entra ID 그룹 멤버십 — AI 개발자 그룹 (기존 ai-developer-users)
#--------------------------------------------------------------


resource "azuread_group_member" "this" {
  for_each = local.member_ids

  group_object_id  = var.group_object_id
  member_object_id = each.value
}
