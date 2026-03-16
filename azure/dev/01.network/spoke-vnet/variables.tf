#--------------------------------------------------------------
# Spoke VNet — 루트에서 전달받는 컨텍스트
#--------------------------------------------------------------
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "name_prefix" {
  description = "리소스 이름 접두사 (루트에서 project_name 기반으로 전달)"
  type        = string
}
variable "hub_vnet_id" { type = string }
variable "hub_resource_group_name" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "private_dns_zone_keys" {
  description = "Set of zone keys for Hub DNS links (static set for plan-time known for_each)"
  type        = set(string)
}
variable "private_dns_zone_names" {
  description = "Static map key => zone FQDN for Hub DNS links"
  type        = map(string)
}
variable "spoke_private_dns_zones" {
  type    = map(string)
  default = {}
}

#--------------------------------------------------------------
# 이 Spoke의 리소스 정보 (기본값은 이 폴더에서 관리, 신규 Spoke는 폴더 복사 후 여기만 수정)
#--------------------------------------------------------------
variable "rg_suffix" {
  description = "Resource Group 이름 접미사 (최종 이름: name_prefix-rg_suffix)"
  type        = string
  default     = "spoke-rg"
}

variable "vnet_suffix" {
  description = "VNet 이름 접미사 (최종 이름: name_prefix-vnet_suffix)"
  type        = string
  default     = "spoke-vnet"
}

variable "vnet_address_space" {
  description = "Spoke VNet 주소 공간"
  type        = list(string)
  default     = ["10.1.0.0/24"]
}

variable "subnets" {
  description = "Spoke 서브넷 구성 (apim-snet, pep-snet 등)"
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
