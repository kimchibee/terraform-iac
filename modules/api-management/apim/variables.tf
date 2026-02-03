#--------------------------------------------------------------
# API Management Module Variables
# 이 디렉터리(모듈)가 외부에서 입력받는 변수 정의 파일
#--------------------------------------------------------------

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
  default     = {}
}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------
variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Virtual Network resource group name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name for API Management"
  type        = string
}

#--------------------------------------------------------------
# API Management Configuration
#--------------------------------------------------------------
variable "apim_name" {
  description = "API Management name"
  type        = string
}

variable "apim_sku_name" {
  description = "API Management SKU"
  type        = string
  default     = "Developer_1"
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
}

#--------------------------------------------------------------
# API Configuration (for frequent changes)
#--------------------------------------------------------------
variable "apis" {
  description = "Map of APIs to create"
  type = map(object({
    display_name = string
    path         = string
    protocols    = list(string)
    service_url  = optional(string, "")
    policy_file  = optional(string, "")
  }))
  default = {}
}

#--------------------------------------------------------------
# Policy Configuration
#--------------------------------------------------------------
variable "policies" {
  description = "Map of policy file paths"
  type = object({
    global_policy = optional(string, "")
    api_policies  = optional(map(string), {})
  })
  default = {}
}

#--------------------------------------------------------------
# Backend Configuration
#--------------------------------------------------------------
variable "backends" {
  description = "Map of backend service configurations"
  type = map(object({
    url                = string
    protocol           = optional(string, "http")
    authentication     = optional(string, "none") # none, managed_identity, certificate
    managed_identity_id = optional(string, "")
  }))
  default = {}
}

#--------------------------------------------------------------
# Log Analytics
#--------------------------------------------------------------
variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Existing Resources (for reuse)
#--------------------------------------------------------------
variable "existing_subnet_id" {
  description = "Existing Subnet ID to use (optional)"
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Key Vault name for secrets (optional)"
  type        = string
  default     = null
}
