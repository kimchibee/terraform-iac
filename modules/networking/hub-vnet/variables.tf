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
# Virtual Machine
#--------------------------------------------------------------
variable "vm_name" {
  description = "Monitoring VM name"
  type        = string
}

variable "vm_size" {
  description = "VM size"
  type        = string
}

variable "vm_admin_username" {
  description = "VM admin username"
  type        = string
}

variable "vm_admin_password" {
  description = "VM admin password"
  type        = string
  sensitive   = true
}

#--------------------------------------------------------------
# Key Vault
#--------------------------------------------------------------
variable "key_vault_name" {
  description = "Key Vault name"
  type        = string
}

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
variable "enable_key_vault" {
  description = "Enable Key Vault deployment"
  type        = bool
  default     = true
}

variable "enable_monitoring_vm" {
  description = "Enable Monitoring VM deployment"
  type        = bool
  default     = true
}

variable "enable_dns_forwarding_ruleset" {
  description = "Enable DNS Forwarding Ruleset deployment"
  type        = bool
  default     = true
}
