#--------------------------------------------------------------
# Compute 루트 변수
# 리소스별 정보(사이즈, OS, 이름 접미사 등)는 각 하위 폴더(linux-monitoring-vm, windows-example 등)의 variables.tf 기본값에서 관리.
# 루트에는 공통·컨텍스트·보안(비밀번호)만 둠. 신규 VM 추가 시 루트에는 module 블록 + (Windows인 경우 admin_password 변수)만 추가.
#--------------------------------------------------------------

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "hub_subscription_id" {
  type = string
}

variable "spoke_subscription_id" {
  type = string
}

variable "backend_resource_group_name" {
  type = string
}

variable "backend_storage_account_name" {
  type = string
}

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

# Network 스택 방화벽 정책(ASG): 루트에서 키만 지정하면 remote_state로 ID 해석. 모든 VM에 공통 적용 가능.
variable "application_security_group_keys" {
  description = "VM NIC에 붙일 방화벽 정책 키. keyvault_clients, vm_allowed_clients 등"
  type        = list(string)
  default     = ["keyvault_clients", "vm_allowed_clients"]
}

# Windows VM 비밀번호만 루트에서 관리 (보안상 tfvars에만 두고 저장소에 올리지 않음). VM별로 하나씩.
# windows-example 외 추가 Windows VM이 있으면 동일하게 변수 추가 (예: windows_app_02_admin_password)
variable "windows_example_admin_password" {
  description = "windows-example VM 로그인 비밀번호. 보안상 루트 tfvars에서만 설정"
  type        = string
  sensitive   = true
}
