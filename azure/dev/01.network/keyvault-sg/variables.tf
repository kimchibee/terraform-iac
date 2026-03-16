#--------------------------------------------------------------
# keyvault-sg 모듈 변수
#--------------------------------------------------------------

variable "resource_group_name" {
  description = "Resource group name for the keyvault-sg NSG (Hub RG)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

# Standalone NSG 생성 여부 및 이름
variable "create_standalone_nsg" {
  description = "Create a dedicated keyvault-sg NSG (for subnets that have no NSG)"
  type        = bool
  default     = true
}

variable "standalone_nsg_name" {
  description = "Name of the standalone keyvault-sg NSG"
  type        = string
}

# 이 NSG를 연결할 서브넷 ID 목록 (이미 다른 NSG가 붙어 있는 서브넷에는 연결 불가 — Azure는 서브넷당 NSG 1개)
variable "subnet_ids_attach_keyvault_sg" {
  description = "Subnet IDs to attach the standalone keyvault-sg NSG to (only subnets that do not already have an NSG)"
  type        = list(string)
  default     = []
}

# Key Vault 아웃바운드 규칙을 추가할 기존 NSG ID 목록 (예: Monitoring VM 서브넷용 NSG)
variable "nsg_ids_add_keyvault_rule" {
  description = "Existing NSG IDs to add the Allow KeyVault outbound (443) rule to"
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# PE 쪽 인바운드 1개 정책 (소스 = ASG, 443) — Monitoring VM + Spoke Linux 등 한 정책으로 통제
# enable_pe_inbound_from_asg = true 시 ASG 생성 후, PE 서브넷 NSG에 인바운드 규칙 1개 추가
#--------------------------------------------------------------
variable "enable_pe_inbound_from_asg" {
  description = "PE subnet NSG에 인바운드 규칙 1개 추가: 소스 = keyvault-clients ASG, 포트 443. Monitoring VM·Spoke Linux 등에 같은 ASG만 붙이면 한 정책으로 허용"
  type        = bool
  default     = false
}

variable "pe_nsg_id" {
  description = "Key Vault Private Endpoint가 붙은 서브넷(pep-snet)의 NSG ARM ID. enable_pe_inbound_from_asg = true 일 때 필수"
  type        = string
  default     = null
}

variable "keyvault_clients_asg_name" {
  description = "Application Security Group 이름 (Key Vault 접근 허용 대상). enable_pe_inbound_from_asg = true 일 때 생성"
  type        = string
  default     = "keyvault-clients-asg"
}
