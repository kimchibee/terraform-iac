#--------------------------------------------------------------
# General Variables
#--------------------------------------------------------------
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------
variable "resource_group_name" {
  description = "Resource group name for shared services"
  type        = string
}

#--------------------------------------------------------------
# Log Analytics
#--------------------------------------------------------------
variable "log_analytics_workspace_name" {
  description = "Log Analytics Workspace name"
  type        = string
}

variable "log_analytics_retention_days" {
  description = "Log Analytics retention in days"
  type        = number
  default     = 30
}

#--------------------------------------------------------------
# Feature Flags
#--------------------------------------------------------------
variable "enable_shared_services" {
  description = "Enable shared services (Security Insights, Action Group, Dashboard)"
  type        = bool
  default     = true
}
