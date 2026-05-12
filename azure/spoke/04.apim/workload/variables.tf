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

# API Management Variables
variable "apim_sku_name" {
  description = "API Management SKU name"
  type        = string
  default     = "Developer_1"
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "platform-team"
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "platform@example.com"
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
