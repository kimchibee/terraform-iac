#--------------------------------------------------------------
# 관리자 그룹 모듈 — 구독 또는 RG 범위 역할 부여
# 루트 rbac에서 호출. provider는 azurerm.hub 전달.
#--------------------------------------------------------------

variable "group_object_id" {
  description = "Azure AD(Entra ID) 보안 그룹 Object ID"
  type        = string
}

variable "scope_id" {
  description = "역할 부여 scope (ARM 리소스 ID). 예: /subscriptions/{id}, 리소스 그룹 ID"
  type        = string
}

variable "role_definition_name" {
  description = "부여할 역할 이름 (예: Contributor, Owner)"
  type        = string
  default     = "Contributor"
}

variable "member_object_ids" {
  description = "이 그룹에 소속시킬 멤버의 Azure AD Object ID 목록 (사용자·그룹·서비스 주체). Terraform으로 등록/변경/삭제."
  type        = list(string)
  default     = []
}
