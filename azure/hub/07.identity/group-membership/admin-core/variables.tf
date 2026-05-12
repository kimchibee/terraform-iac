variable "project_name" {
  description = "Project name prefix (메타데이터)"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags (이 스택은 리소스 그룹을 만들지 않음 — 참고용)"
  type        = map(string)
  default     = {}
}

variable "group_object_id" {
  description = "관리자 그룹(Entra ID) Object ID"
  type        = string
}

variable "member_object_ids" {
  description = "그룹 멤버 Object ID 목록"
  type        = list(string)
  default     = []
}
