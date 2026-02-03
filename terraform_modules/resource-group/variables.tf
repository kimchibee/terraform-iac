#-------------------------------------------------------------------------------
# Resource Group 모듈 - 입력 변수
# 단일 책임: Resource Group 1개만 생성
#-------------------------------------------------------------------------------

variable "name" {
  description = "Resource Group 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "tags" {
  description = "공통 태그 (호출 측에서 환경별로 전달)"
  type        = map(string)
  default     = {}
}
