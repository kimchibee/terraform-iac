#-------------------------------------------------------------------------------
# VNet 모듈 - 입력 변수
# 단일 책임: Virtual Network 및 서브넷만 생성 (Resource Group은 호출 측에서 관리)
# 환경(dev/stage/prod) 값은 호출 측(terraform-infra)에서 주입
#-------------------------------------------------------------------------------

variable "project_name" {
  description = "프로젝트 이름 (리소스 네이밍·태그에 사용)"
  type        = string
}

variable "environment" {
  description = "환경 식별자 (예: dev, stage, prod). 호출 측에서 전달."
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "resource_group_name" {
  description = "대상 Resource Group 이름 (호출 측에서 생성 후 전달)"
  type        = string
}

variable "vnet_name" {
  description = "Virtual Network 이름"
  type        = string
}

variable "vnet_address_space" {
  description = "VNet 주소 공간 (CIDR 목록)"
  type        = list(string)
}

variable "subnets" {
  description = "서브넷 설정 (이름을 키로, 설정을 값으로)"
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
  default = {}
}

variable "tags" {
  description = "공통 태그 (호출 측에서 환경별로 전달)"
  type        = map(string)
  default     = {}
}
