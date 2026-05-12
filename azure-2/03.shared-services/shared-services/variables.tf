#--------------------------------------------------------------
# Shared Services — 루트에서 전달받는 컨텍스트
#--------------------------------------------------------------
variable "resource_group_name" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "log_analytics_workspace_name" { type = string }
variable "project_name" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }

#--------------------------------------------------------------
# 이 리소스의 정보 (기본값은 이 폴더에서 관리)
#--------------------------------------------------------------
variable "enable" {
  description = "Shared Services 배포 여부"
  type        = bool
  default     = true
}
