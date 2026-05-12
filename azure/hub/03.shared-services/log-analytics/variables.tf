#--------------------------------------------------------------
# Shared Services Stack Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
}

variable "name_suffix" {
  description = "Log Analytics Workspace 이름 접미사"
  type        = string
  default     = "law"
}

variable "retention_in_days" {
  description = "Log Analytics Workspace 로그 보존 일수"
  type        = number
  default     = 30
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
