variable "project_name" {
  description = "Project name prefix (NSG 진단 설정 이름 등)"
  type        = string
}

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
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
