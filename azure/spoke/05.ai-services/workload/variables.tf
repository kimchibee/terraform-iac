#--------------------------------------------------------------
# AI Services Stack Variables
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

variable "hub_subscription_id" {
  description = "Hub subscription ID (used for private DNS zone record management)"
  type        = string
}

# Spoke-workloads: network/connectivity에서 이미 생성하는 리소스는 생성하지 않음
variable "enable_spoke_to_hub_peering" {
  description = "Spoke→Hub VNet Peering 생성 여부 (connectivity 스택에서 관리 시 false)"
  type        = bool
  default     = false
}

variable "enable_private_dns_zone_links" {
  description = "Private DNS Zone VNet Link 생성 여부 (network 스택에서 관리 시 false)"
  type        = bool
  default     = false
}

variable "enable_pep_nsg" {
  description = "Spoke PEP용 NSG 생성 여부 (network 스택에서 관리 시 false)"
  type        = bool
  default     = false
}

# Backend Configuration (for remote_state)

# Azure OpenAI Variables
variable "openai_sku" {
  description = "Azure OpenAI SKU"
  type        = string
  default     = "S0"
}

variable "openai_deployments" {
  description = "Azure OpenAI deployments"
  type = list(object({
    name       = string
    model_name = string
    version    = string
    capacity   = number
    scale_type = optional(string, "Standard")
  }))
  default = []
}

variable "enable_ai_foundry_workspace" {
  description = "Enable AI Foundry (Azure ML workspace) provisioning"
  type        = bool
  default     = true
}

variable "enable_private_endpoints" {
  description = "Enable Private Endpoint provisioning for OpenAI and AI Foundry"
  type        = bool
  default     = true
}

variable "hub_backend_resource_group_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "hub_backend_storage_account_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage account 이름"
}

variable "hub_backend_container_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage container 이름"
}

variable "spoke_backend_resource_group_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "spoke_backend_storage_account_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage account 이름"
}

variable "spoke_backend_container_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage container 이름"
}
