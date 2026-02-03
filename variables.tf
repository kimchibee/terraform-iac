#--------------------------------------------------------------
# General Variables
#--------------------------------------------------------------
variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "test"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Korea Central"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "test"
    ManagedBy   = "Terraform"
    Project     = "Azure-Hub-Spoke"
  }
}

#--------------------------------------------------------------
# Subscription Variables
#--------------------------------------------------------------
variable "hub_subscription_id" {
  description = "Hub subscription ID (x-x-x-root-test)"
  type        = string
}

variable "spoke_subscription_id" {
  description = "Spoke subscription ID (x-x-x-generative-test)"
  type        = string
}

#--------------------------------------------------------------
# Hub Network Variables
#--------------------------------------------------------------
variable "hub_vnet_address_space" {
  description = "Hub VNet address space"
  type        = list(string)
  default     = ["10.0.0.0/20"]
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
  default = {
    "GatewaySubnet" = {
      address_prefixes = ["10.0.0.0/26"]
    }
    "DNSResolver-Inbound" = {
      address_prefixes = ["10.0.0.64/28"]
      delegation = {
        name         = "Microsoft.Network.dnsResolvers"
        service_name = "Microsoft.Network/dnsResolvers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    "DNSResolver-Outbound" = {
      address_prefixes = ["10.0.0.80/28"]
      delegation = {
        name         = "Microsoft.Network.dnsResolvers"
        service_name = "Microsoft.Network/dnsResolvers"
        actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
    "Monitoring-VM-Subnet" = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
    "AzureFirewallSubnet" = {
      address_prefixes = ["10.0.2.0/26"]
    }
    "AzureFirewallManagementSubnet" = {
      address_prefixes = ["10.0.2.64/26"]
    }
    "AppGatewaySubnet" = {
      address_prefixes = ["10.0.3.0/24"]
    }
    "pep-snet" = {
      address_prefixes                  = ["10.0.4.0/24"]
      private_endpoint_network_policies = "Disabled"
      service_endpoints                 = ["Microsoft.Storage", "Microsoft.KeyVault"]
    }
  }
}

#--------------------------------------------------------------
# Spoke Network Variables
#--------------------------------------------------------------
variable "spoke_vnet_address_space" {
  description = "Spoke VNet address space"
  type        = list(string)
  default     = ["10.1.0.0/24"]
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
  default = {
    "apim-snet" = {
      address_prefixes  = ["10.1.0.0/26"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
    }
    "pep-snet" = {
      address_prefixes                  = ["10.1.0.64/26"]
      private_endpoint_network_policies = "Disabled"
    }
  }
}

#--------------------------------------------------------------
# VPN Gateway Variables
#--------------------------------------------------------------
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
  description = "Local network gateway configurations for on-premises connections"
  type = list(object({
    name            = string
    gateway_address = string
    address_space   = list(string)
    bgp_settings = optional(object({
      asn                 = number
      bgp_peering_address = string
    }))
  }))
  default = [
    {
      name            = "lgw-01"
      gateway_address = "203.0.113.1" # Replace with actual on-prem gateway IP
      address_space   = ["192.168.0.0/16"]
    }
  ]
}

variable "vpn_shared_key" {
  description = "Shared key for VPN connections"
  type        = string
  sensitive   = true
  default     = ""
}

#--------------------------------------------------------------
# VM Variables
#--------------------------------------------------------------
variable "vm_size" {
  description = "Size of the monitoring VM"
  type        = string
  default     = "Standard_B2s"
}

variable "vm_admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "azureadmin"
}

variable "vm_admin_password" {
  description = "Admin password for VM"
  type        = string
  sensitive   = true
  default     = ""
}

#--------------------------------------------------------------
# API Management Variables
#--------------------------------------------------------------
variable "apim_sku_name" {
  description = "API Management SKU"
  type        = string
  default     = "Developer_1"
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "Test Organization"
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "admin@example.com"
}

#--------------------------------------------------------------
# Azure OpenAI Variables
#--------------------------------------------------------------
variable "openai_sku" {
  description = "Azure OpenAI SKU"
  type        = string
  default     = "S0"
}

variable "openai_deployments" {
  description = "Azure OpenAI model deployments"
  type = list(object({
    name       = string
    model_name = string
    version    = string
    capacity   = number
  }))
  default = [
    {
      name       = "gpt-4-1-mini"
      model_name = "gpt-4"
      version    = "0125-Preview"
      capacity   = 10
    },
    {
      name       = "gpt-5-mini"
      model_name = "gpt-4"
      version    = "turbo-2024-04-09"
      capacity   = 10
    }
  ]
}

#--------------------------------------------------------------
# Log Analytics Variables
#--------------------------------------------------------------
variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
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

variable "enable_shared_services" {
  description = "Enable shared services (Security Insights, Action Group, Dashboard)"
  type        = bool
  default     = true
}
