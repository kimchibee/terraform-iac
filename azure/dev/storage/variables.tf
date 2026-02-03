#--------------------------------------------------------------
# Storage Stack Variables
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
variable "hub_subscription_id" {
  description = "Hub subscription ID"
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

# Feature Flags
variable "enable_key_vault" {
  description = "Enable Key Vault deployment"
  type        = bool
  default     = true
}

variable "enable_monitoring_vm" {
  description = "Enable Monitoring VM (for role assignments)"
  type        = bool
  default     = false
}

variable "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity Principal ID (from compute stack)"
  type        = string
  default     = ""
}
