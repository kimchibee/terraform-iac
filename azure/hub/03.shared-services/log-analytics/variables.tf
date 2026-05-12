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

variable "backend_resource_group_name" {
  description = "Backend storage account resource group name"
  type        = string
}

variable "backend_storage_account_name" {
  description = "Backend storage account name"
  type        = string
}

variable "backend_container_name" {
  description = "Backend container name"
  type        = string
  default     = "tfstate"
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
