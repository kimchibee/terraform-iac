#--------------------------------------------------------------
# RBAC Stack Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags for role assignments (metadata)"
  type        = map(string)
  default     = {}
}

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
}

variable "spoke_subscription_id" {
  description = "Spoke subscription ID"
  type        = string
}

variable "backend_resource_group_name" {
  description = "Backend storage resource group (for remote_state)"
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

# compute 스택에서 Monitoring VM을 사용할 때만 역할 부여
variable "enable_monitoring_vm_roles" {
  description = "Monitoring VM에 Hub/Spoke 리소스 접근 역할 부여 (compute 스택에서 VM 사용 시 true)"
  type        = bool
  default     = true
}

variable "enable_key_vault_roles" {
  description = "Hub Key Vault 관련 역할 부여 (storage 스택에 Key Vault 있을 때 true)"
  type        = bool
  default     = true
}
