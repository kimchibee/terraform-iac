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

variable "iam_role_assignments" {
  description = "Spoke 구독??부?�할 ??���?(use_spoke_provider = true)"
  type = list(object({
    principal_id         = string
    role_definition_name = string
    use_spoke_provider   = optional(bool, false)
    scope_ref            = optional(string)
    scope                = optional(string)
  }))
  default = []
}
