#-------------------------------------------------------------------------------
# Private Endpoint 모듈 - 입력 변수
# 단일 책임: 대상 리소스 1개에 대한 Private Endpoint 1개 + (선택) Private DNS Zone 연결
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
  description = "Private Endpoint 이름 (예: pe-xxx-blob, pe-hub-kv)"
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

variable "subnet_id" {
  description = "Private Endpoint를 만들 서브넷 ID (일반적으로 pep-snet)"
  type        = string
}

variable "target_resource_id" {
  description = "연결할 대상 리소스 ID (Storage Account, Key Vault, OpenAI 등)"
  type        = string
}

variable "subresource_names" {
  description = "대상 서브리소스 이름 (예: blob, vault, file, sqlServer)"
  type        = list(string)
}

variable "private_connection_name" {
  description = "Private Service Connection 이름 (비우면 name 사용)"
  type        = string
  default     = null
}

variable "private_dns_zone_ids" {
  description = "Private DNS Zone ID 목록 (지정 시 private_dns_zone_group 생성)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "공통 태그"
  type        = map(string)
  default     = {}
}
