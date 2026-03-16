#--------------------------------------------------------------
# ai-developer-users — 그룹 멤버십 관리 (등록/변경/삭제)
#--------------------------------------------------------------

variable "group_object_id" {
  description = "Azure AD(Entra ID) 그룹 Object ID"
  type        = string
}

variable "member_object_ids" {
  description = "그룹에 소속시킬 멤버의 Object ID 목록 (사용자·그룹·서비스 주체). 목록에서 제거 시 Terraform apply 시 해당 멤버가 그룹에서 제거됨."
  type        = list(string)
  default     = []
}
