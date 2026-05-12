variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "group_object_id" {
  description = "AI 개발??그룹(Entra ID) Object ID"
  type        = string
}

variable "member_object_ids" {
  type    = list(string)
  default = []
}
