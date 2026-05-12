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
  type = string
}

variable "iam_role_assignments" {
  description = "Role assignments to create in the Hub subscription (use_spoke_provider = false)."
  type = list(object({
    principal_id         = string
    role_definition_name = string
    use_spoke_provider   = optional(bool, false)
    scope_ref            = optional(string)
    scope                = optional(string)
  }))
  default = []
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

variable "spoke_backend_resource_group_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "spoke_backend_storage_account_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage account 이름"
}

variable "spoke_backend_container_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage container 이름"
}
