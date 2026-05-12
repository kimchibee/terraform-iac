#--------------------------------------------------------------
# Network Stack Variables
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

# Hub Network Variables
variable "hub_vnet_address_space" {
  description = "Hub VNet address space"
  type        = list(string)
}

variable "hub_subnets" {
  description = "Hub subnet configurations (keys must match subnet names in locals.tf)"
  type = map(object({
    address_prefixes                      = list(string)
    service_endpoints                     = optional(list(string), [])
    private_endpoint_network_policies     = optional(string, "Disabled")
    private_link_service_network_policies = optional(string, "Disabled")
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
}

# Spoke Network — 주소 공간·서브넷은 spoke-vnet 폴더 variables.tf 기본값에서 관리.
# 신규 Spoke 추가 시 해당 폴더 복사 후 그 폴더만 수정하고, 루트에는 module 블록만 추가.

# Spoke-owned Private DNS Zones (image: zones in both Hub and Spoke)
variable "spoke_private_dns_zones" {
  description = "Private DNS Zones to create in Spoke (key = logical name, value = zone FQDN). Default: APIM, OpenAI, AI Foundry zones."
  type        = map(string)
  default     = null
}

# VPN Gateway Variables
variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU"
  type        = string
  default     = "VpnGw1"
}

variable "vpn_gateway_type" {
  description = "VPN Gateway type"
  type        = string
  default     = "Vpn"
}

variable "local_gateway_configs" {
  description = "Local network gateway configurations"
  type = list(object({
    name            = string
    gateway_address = string
    address_space   = list(string)
    bgp_settings = optional(object({
      asn                 = number
      bgp_peering_address = string
    }))
  }))
  default = []
}

variable "vpn_shared_key" {
  description = "VPN shared key"
  type        = string
  sensitive   = true
  default     = ""
}

# API Management Variables - 제거됨 (apim 스택에서 관리)
# Azure OpenAI Variables - 제거됨 (ai-services 스택에서 관리)

# Feature Flags
variable "enable_dns_forwarding_ruleset" {
  description = "Enable DNS Forwarding Ruleset deployment"
  type        = bool
  default     = true
}

# keyvault-sg / vm-access-sg 변수는 `subnet/hub-pep-subnet` 리프에서 관리

variable "create_hub_resource_group" {
  description = "true면 Hub RG를 hub-vnet 모듈에서 생성. 새 구조에서는 `01.network/resource-group/hub-rg` 선행 후 false 사용이 기본."
  type        = bool
  default     = false
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
