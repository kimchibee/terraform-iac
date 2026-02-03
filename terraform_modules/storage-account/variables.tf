#-------------------------------------------------------------------------------
# Storage Account 모듈 - 입력 변수
# 단일 책임: Storage Account 1개 및 기본 설정만 생성
# 환경 값은 호출 측(terraform-infra)에서 주입
#-------------------------------------------------------------------------------

variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍·태그에 사용)"
  type        = string
}

variable "environment" {
  description = "환경 식별자 (예: dev, stage, prod)"
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

variable "storage_account_name" {
  description = "Storage Account 이름 (3~24자, 소문자+숫자만, 전역 유일). 비우면 name_prefix + 랜덤 4자로 생성"
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "storage_account_name이 없을 때 사용할 접두사 (이름 = prefix + 랜덤 4자)"
  type        = string
  default     = ""
}

variable "account_tier" {
  description = "스토리지 계정 티어 (Standard / Premium)"
  type        = string
  default     = "Standard"
}

variable "account_replication_type" {
  description = "복제 유형 (LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS)"
  type        = string
  default     = "LRS"
}

variable "min_tls_version" {
  description = "최소 TLS 버전 (TLS1_0, TLS1_1, TLS1_2)"
  type        = string
  default     = "TLS1_2"
}

variable "public_network_access_enabled" {
  description = "퍼블릭 네트워크 접근 허용 여부 (Private Endpoint만 쓰면 false 권장)"
  type        = bool
  default     = true
}

variable "network_rules" {
  description = "네트워크 규칙 (default_action, bypass, subnet_ids 등). null이면 규칙 미적용"
  type = object({
    default_action             = string # Deny / Allow
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
