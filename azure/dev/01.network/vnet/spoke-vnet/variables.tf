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

variable "backend_resource_group_name" {
  type = string
}

variable "backend_storage_account_name" {
  type = string
}

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

variable "spoke_private_dns_zones" {
  description = "Spoke????Private DNS Zone (Hub?� 중복 ?�임?�페?�스 ?�외). null?�면 기본 �??�용."
  type        = map(string)
  default     = null
}

variable "rg_suffix" {
  description = "Resource Group ?�름 ?��???(최종: name_prefix-rg_suffix)"
  type        = string
  default     = "spoke-rg"
}

variable "vnet_suffix" {
  description = "VNet ?�름 ?��???
  type        = string
  default     = "spoke-vnet"
}

variable "vnet_address_space" {
  description = "Spoke VNet 주소 공간"
  type        = list(string)
  default     = ["10.1.0.0/24"]
}

variable "subnets" {
  description = "Spoke ?�브??구성"
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
