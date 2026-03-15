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
  description = "Spoke subnet configurations (keys must match subnet names in locals.tf)"
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

#--------------------------------------------------------------
# 시나리오 3: keyvault-sg (Key Vault 접근 허용 NSG 규칙)
# Key Vault PE는 storage 스택에서 Hub VNet pep-snet 사용
#--------------------------------------------------------------
variable "enable_keyvault_sg" {
  description = "Enable keyvault-sg: NSG 규칙으로 Key Vault(443) 아웃바운드 허용"
  type        = bool
  default     = false
}

variable "hub_subnet_names_attach_keyvault_sg" {
  description = "Hub 서브넷 이름 목록: standalone keyvault-sg NSG를 연결할 서브넷 (이미 다른 NSG가 붙어 있으면 사용 불가)"
  type        = list(string)
  default     = []
}

variable "hub_nsg_keys_add_keyvault_rule" {
  description = "Key Vault 아웃바운드 규칙을 추가할 Hub NSG 키: monitoring_vm, pep 중 하나 이상"
  type        = list(string)
  default     = []
}

# PE 쪽 인바운드 1개 정책 (소스 = ASG, 443) — Monitoring VM + Spoke Linux 등 한 정책으로 통제
variable "enable_pe_inbound_from_asg" {
  description = "PE(pep-snet) NSG에 인바운드 1개: 소스=keyvault-clients ASG, 포트 443. output keyvault_clients_asg_id를 VM NIC에 붙이면 한 정책으로 허용"
  type        = bool
  default     = false
}

variable "keyvault_clients_asg_name" {
  description = "Key Vault 접근 허용용 ASG 이름 (enable_pe_inbound_from_asg = true 시 생성)"
  type        = string
  default     = "keyvault-clients-asg"
}

#--------------------------------------------------------------
# VM 타겟 단일 정책 (ASG): 타겟 VM NSG 인바운드 = 소스 ASG, 포트 22/3389 등
# 허용할 클라이언트 VM NIC에 vm_allowed_clients_asg_id 붙이면 VNet 무관 단일 정책
#--------------------------------------------------------------
variable "enable_vm_access_sg" {
  description = "VM 접근 허용용 ASG + 타겟 NSG 인바운드 규칙 생성 (단일 정책으로 VM 접속 제어)"
  type        = bool
  default     = false
}

variable "vm_allowed_clients_asg_name" {
  description = "VM 접속 허용 클라이언트 ASG 이름"
  type        = string
  default     = "vm-allowed-clients-asg"
}

variable "vm_access_target_nsg_keys" {
  description = "타겟 VM NSG 키 (Hub): monitoring_vm, pep 등. 해당 NSG에 인바운드(소스=ASG, 포트) 추가"
  type        = list(string)
  default     = []
}

variable "vm_access_target_nsg_ids_extra" {
  description = "타겟 VM NSG ID 추가 목록 (Hub 구독 내). vm_access_target_nsg_keys와 병합"
  type        = list(string)
  default     = []
}

variable "vm_access_target_nsg_ids_spoke" {
  description = "타겟 VM NSG ID 목록 (Spoke 구독). Spoke VM 접근 허용 시 해당 VM 서브넷 NSG ID"
  type        = list(string)
  default     = []
}

variable "vm_access_destination_ports" {
  description = "VM 접속 허용 포트 (22=SSH, 3389=RDP, 443 등)"
  type        = list(string)
  default     = ["22", "3389"]
}
