#--------------------------------------------------------------
# 변수 기반 IAM 역할 할당 — Spoke 구독 (use_spoke_provider = true)
#--------------------------------------------------------------


resource "azurerm_role_assignment" "resource_iam_spoke" {
  for_each = local.iam_for_spoke

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
