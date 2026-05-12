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

# Key Vault / Monitoring VM 플래그 — 이 파일 기본값에서 관리

variable "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity Principal ID (from compute stack)"
  type        = string
  default     = ""
}

variable "key_vault_suffix" {
  description = "Key Vault 이름 접미사 (최종 이름: project_name-key_vault_suffix)"
  type        = string
  default     = "hub-kv"
}

variable "enable_key_vault" {
  description = "Key Vault 배포 여부"
  type        = bool
  default     = true
}

variable "enable_monitoring_vm" {
  description = "Monitoring VM용 역할 할당 등 적용 여부"
  type        = bool
  default     = false
}
