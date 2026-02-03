#--------------------------------------------------------------
# General Variables
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
  description = "Tags for resources"
  type        = map(string)
}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------
variable "resource_group_name" {
  description = "Hub resource group name"
  type        = string
}

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
variable "vnet_name" {
  description = "Hub VNet name"
  type        = string
}

variable "vnet_address_space" {
  description = "Hub VNet address space"
  type        = list(string)
}

variable "subnets" {
  description = "Subnet configurations"
  type = map(object({
    address_prefixes                      = list(string)
    service_endpoints                     = optional(list(string), [])
    private_endpoint_network_policies     = optional(string, "Disabled")
    private_link_service_network_policies = optional(string, "Disabled")
    delegation                            = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
}

#--------------------------------------------------------------
# VPN Gateway
#--------------------------------------------------------------
variable "vpn_gateway_name" {
  description = "VPN Gateway name"
  type        = string
}

variable "vpn_gateway_sku" {
  description = "VPN Gateway SKU"
  type        = string
}

variable "vpn_gateway_type" {
  description = "VPN Gateway type"
  type        = string
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
}

variable "vpn_shared_key" {
  description = "VPN shared key"
  type        = string
  sensitive   = true
}

#--------------------------------------------------------------
# DNS Private Resolver
#--------------------------------------------------------------
variable "dns_resolver_name" {
  description = "DNS Private Resolver name"
  type        = string
}

#--------------------------------------------------------------
# Virtual Machine (Removed - VM is managed by separate module)
#--------------------------------------------------------------
# VM은 루트 main.tf의 module.monitoring_vm에서 관리됨
# hub_vnet 모듈은 네트워크 리소스만 관리하여 독립적으로 배포 가능

#--------------------------------------------------------------
# Key Vault (Removed - Key Vault is managed by storage module)
#--------------------------------------------------------------
# Key Vault는 modules/dev/hub/monitoring-storage 모듈에서 관리됨
# hub_vnet 모듈은 네트워크 리소스만 관리하여 독립적으로 배포 가능

#--------------------------------------------------------------
# Log Analytics
#--------------------------------------------------------------
variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostics"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Feature Flags
#--------------------------------------------------------------
# Feature flags removed - hub_vnet 모듈은 네트워크 리소스만 관리
# Key Vault와 VM은 별도 모듈에서 관리

variable "enable_dns_forwarding_ruleset" {
  description = "Enable DNS Forwarding Ruleset deployment"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# Storage Account IDs for Diagnostic Settings (Removed)
#--------------------------------------------------------------
# 진단 설정은 루트 모듈에서 관리하여 모듈 간 순환 의존성을 제거합니다.
# hub_vnet 모듈은 네트워크 리소스만 관리하고 완전히 독립적으로 배포 가능합니다.
