#--------------------------------------------------------------
# API Management Stack Variables
#--------------------------------------------------------------

# General Variables
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

# Subscription Variables
variable "spoke_subscription_id" {
  description = "Spoke subscription ID"
  type        = string
}

# Backend Configuration (for remote_state)
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

# API Management Variables
variable "apim_sku_name" {
  description = "API Management SKU name"
  type        = string
  default     = "Developer"
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = ""
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = ""
}
