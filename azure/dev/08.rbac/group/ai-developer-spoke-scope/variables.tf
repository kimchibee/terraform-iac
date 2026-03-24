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

variable "spoke_subscription_id" {
  type = string
}

variable "backend_resource_group_name" {
  type = string
}

variable "backend_storage_account_name" {
  type = string
}

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

variable "ai_developer_group_object_id" {
  description = "AI 개발??그룹 Object ID. 미설??????�� ?�당 ?�음."
  type        = string
  default     = null
}

variable "spoke_rg_role_definition_name" {
  description = "Spoke RG ??��"
  type        = string
  default     = "Reader"
}
