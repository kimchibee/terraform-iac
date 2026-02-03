#--------------------------------------------------------------
# Storage Module Variables
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
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

variable "key_vault_name" {
  description = "Key Vault name"
  type        = string
  default     = ""
}

variable "enable_key_vault" {
  description = "Enable Key Vault deployment"
  type        = bool
  default     = true
}

variable "monitoring_vm_subnet_id" {
  description = "Monitoring VM Subnet ID"
  type        = string
}

variable "pep_subnet_id" {
  description = "Private Endpoint Subnet ID"
  type        = string
}

variable "private_dns_zone_ids" {
  description = "Private DNS Zone IDs map"
  type = map(string)
  default = {}
}

variable "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity Principal ID"
  type        = string
  default     = ""
}

variable "enable_monitoring_vm" {
  description = "Enable Monitoring VM"
  type        = bool
  default     = false
}
