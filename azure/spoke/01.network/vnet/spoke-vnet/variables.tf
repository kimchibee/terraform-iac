variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "hub_subscription_id" {
  type = string
}

variable "spoke_subscription_id" {
  type = string
}

variable "spoke_private_dns_zones" {
  description = "Private DNS zones for Spoke resources. Use null to apply default map."
  type        = map(string)
  default     = null
}

variable "rg_suffix" {
  description = "Resource group suffix (final name: name_prefix-rg_suffix)."
  type        = string
  default     = "spoke-rg"
}

variable "vnet_suffix" {
  description = "VNet name suffix (final name: name_prefix-vnet_suffix)"
  type        = string
  default     = "spoke-vnet"
}

variable "vnet_address_space" {
  description = "Spoke VNet 주소 공간"
  type        = list(string)
  default     = ["10.1.0.0/24"]
}

variable "subnets" {
  description = "Spoke subnet definitions."
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
