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

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
}

variable "admin_group_object_id" {
  description = "관리자 그룹 Object ID. 미설??????�� ?�당 ?�성 ????"
  type        = string
  default     = null
}

variable "admin_group_scope_id" {
  description = "??�� 부??scope (ARM 리소??ID)"
  type        = string
  default     = null
}

variable "role_definition_name" {
  description = "부?�할 ??�� ?�름"
  type        = string
  default     = "Contributor"
}
