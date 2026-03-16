#--------------------------------------------------------------
# Monitoring Storage — 루트에서 전달받는 컨텍스트 (remote_state 기반)
#--------------------------------------------------------------
variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "monitoring_vm_subnet_id" { type = string }
variable "pep_subnet_id" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "monitoring_vm_identity_principal_id" {
  description = "Monitoring VM Managed Identity Principal ID (루트에서 remote_state 또는 fallback 변수로 전달)"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# 이 리소스의 정보 (기본값은 이 폴더에서 관리, 신규 인스턴스는 폴더 복사 후 여기만 수정)
#--------------------------------------------------------------
variable "key_vault_suffix" {
  description = "Key Vault 이름 접미사 (최종 이름: project_name-key_vault_suffix)"
  type        = string
  default     = "hub-kv"
}

variable "enable_key_vault" {
  description = "Key Vault 배포 여부"
  type        = bool
  default     = true
}

variable "enable_monitoring_vm" {
  description = "Monitoring VM용 역할 할당 등 적용 여부"
  type        = bool
  default     = false
}
