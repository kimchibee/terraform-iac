#--------------------------------------------------------------
# Connectivity Stack Variables
#--------------------------------------------------------------

# General Variables
variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
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
