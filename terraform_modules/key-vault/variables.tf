#-------------------------------------------------------------------------------
# Key Vault 모듈 - 입력 변수
# 단일 책임: Key Vault 1개 및 기본 설정만 생성 (Private Endpoint는 private-endpoint 모듈 사용)
#-------------------------------------------------------------------------------

variable "project_name" {
  description = "프로젝트 이름 (태그·네이밍 참고용)"
  type        = string
}

variable "environment" {
  description = "환경 식별자 (예: dev, stage, prod)"
  type        = string
}

variable "name" {
  description = "Key Vault 이름 (3~24자, 영숫자·하이픈만, 전역 유일)"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "resource_group_name" {
  description = "대상 Resource Group 이름"
  type        = string
}

variable "sku_name" {
  description = "SKU (standard / premium)"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Soft delete 보존 일수 (7~90)"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Purge 보호 활성화 (prod 권장 true)"
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "퍼블릭 네트워크 접근 허용 (Private Endpoint만 쓰면 false)"
  type        = bool
  default     = true
}

variable "network_acls" {
  description = "네트워크 ACL. null이면 기본 허용"
  type = object({
    default_action             = string   # Deny / Allow
    bypass                     = optional(list(string), ["AzureServices"])
    virtual_network_subnet_ids  = optional(list(string), [])
    ip_rules                   = optional(list(string), [])
  })
  default = null
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
