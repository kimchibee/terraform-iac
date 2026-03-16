#--------------------------------------------------------------
# AI 개발자 그룹 모듈 — Spoke RG + OpenAI 등 AI 리소스 역할 부여
# 루트 rbac에서 호출. provider는 azurerm.spoke 전달.
#--------------------------------------------------------------

variable "group_object_id" {
  description = "Azure AD(Entra ID) 보안 그룹 Object ID"
  type        = string
}

variable "spoke_resource_group_id" {
  description = "Spoke 리소스 그룹 ID (역할 부여 scope)"
  type        = string
}

variable "spoke_rg_role_definition_name" {
  description = "Spoke RG에 부여할 역할 (예: Reader)"
  type        = string
  default     = "Reader"
}

variable "openai_id" {
  description = "Azure OpenAI 리소스 ID (null이면 OpenAI 역할 할당 안 함)"
  type        = string
  default     = null
}

variable "member_object_ids" {
  description = "이 그룹에 소속시킬 멤버의 Azure AD Object ID 목록. Terraform으로 등록/변경/삭제."
  type        = list(string)
  default     = []
}
