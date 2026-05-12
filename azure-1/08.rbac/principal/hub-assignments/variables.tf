variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "hub_subscription_id" {
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

variable "enable_monitoring_vm_roles" {
  description = "Enable RBAC role assignments for monitoring VM managed identity"
  type        = bool
  default     = true
}

variable "enable_key_vault_roles" {
  type    = bool
  default = true
}
