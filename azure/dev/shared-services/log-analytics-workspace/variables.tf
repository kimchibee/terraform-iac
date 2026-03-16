#--------------------------------------------------------------
# Log Analytics Workspace — 루트에서 전달받는 컨텍스트
#--------------------------------------------------------------
variable "name_prefix" {
  description = "리소스 이름 접두사 (루트에서 project_name 기반으로 전달)"
  type        = string
}
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

#--------------------------------------------------------------
# 이 리소스의 정보 (기본값은 이 폴더에서 관리)
#--------------------------------------------------------------
variable "name_suffix" {
  description = "Workspace 이름 접미사 (최종 이름: name_prefix-name_suffix)"
  type        = string
  default     = "law"
}

variable "retention_in_days" {
  description = "로그 보존 일수"
  type        = number
  default     = 30
}
