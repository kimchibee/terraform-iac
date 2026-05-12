#--------------------------------------------------------------
# 변수 기반 IAM 역할 할당 — Hub 구독 (iam_role_assignments, use_spoke_provider = false)
#--------------------------------------------------------------


resource "azurerm_role_assignment" "resource_iam_hub" {
  for_each = local.iam_for_hub

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}
