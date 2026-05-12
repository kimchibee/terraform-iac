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
  description = "Admin group object ID. Leave null to skip role assignment."
  type        = string
  default     = null
}

variable "admin_group_scope_id" {
  description = "Scope ARM resource ID where the role assignment is created."
  type        = string
  default     = null
}

variable "role_definition_name" {
  description = "Role definition name to assign."
  type        = string
  default     = "Contributor"
}
