#--------------------------------------------------------------
# Compute Stack Variables
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

# VM Variables
variable "vm_size" {
  description = "Size of the monitoring VM (Korea Central 가용량 제한 시 Standard_D2s_v3, Standard_B2ms 등 사용)"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "vm_admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureadmin"
}

# VM 접근은 PEM 키로만 함. Terraform이 SSH 키 쌍을 생성하고 개인키를 아래 파일명으로 저장
variable "vm_ssh_private_key_filename" {
  description = "Monitoring VM SSH 개인키 저장 파일명 (compute 스택 디렉터리 기준). .gitignore 대상."
  type        = string
  default     = "monitoring_vm_key.pem"
}

# Feature Flags
variable "enable_monitoring_vm" {
  description = "Enable Monitoring VM deployment"
  type        = bool
  default     = true
}

variable "enable_key_vault" {
  description = "Enable Key Vault (for role assignments)"
  type        = bool
  default     = true
}
