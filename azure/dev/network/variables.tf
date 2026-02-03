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
  description = "Hub subnet configurations"
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

# Spoke Network Variables
variable "spoke_vnet_address_space" {
  description = "Spoke VNet address space"
  type        = list(string)
}

variable "spoke_subnets" {
  description = "Spoke subnet configurations"
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
