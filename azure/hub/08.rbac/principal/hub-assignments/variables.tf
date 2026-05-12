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

variable "enable_monitoring_vm_roles" {
  description = "Enable RBAC role assignments for monitoring VM managed identity"
  type        = bool
  default     = true
}

variable "enable_key_vault_roles" {
  type    = bool
  default = true
}

variable "hub_backend_resource_group_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "hub_backend_storage_account_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage account 이름"
}

variable "hub_backend_container_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage container 이름"
}
