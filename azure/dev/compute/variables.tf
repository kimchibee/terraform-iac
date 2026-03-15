#--------------------------------------------------------------
# Compute 루트 변수
# 신규 스택 추가 시 여기에 변수 추가 후 terraform.tfvars 에 값 설정
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

# Network 스택 방화벽 정책(ASG): 변수명(키)으로 지정. ID 직접 조회 없이 키만 넣으면 remote_state에서 자동 해석
# 사용 가능 키: keyvault_clients, vm_allowed_clients (network에서 해당 정책 활성화 시)
variable "application_security_group_keys" {
  description = "VM NIC에 붙일 방화벽 정책 키. keyvault_clients(Key Vault 접근), vm_allowed_clients(VM 접속 허용). ID 조회 불필요"
  type        = list(string)
  default     = ["keyvault_clients", "vm_allowed_clients"]
}

# --- Linux Monitoring VM ---
variable "linux_monitoring_vm_name" {
  description = "VM 식별 이름 (예: monitoring-vm)"
  type        = string
  default     = "monitoring-vm"
}

variable "linux_monitoring_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "linux_monitoring_vm_admin_username" {
  type    = string
  default = "azureadmin"
}

variable "linux_monitoring_vm_ssh_key_filename" {
  description = "SSH 개인키 파일명 (compute 루트에 저장). .gitignore 대상"
  type        = string
  default     = "linux_monitoring_vm_key.pem"
}

variable "linux_monitoring_vm_enable" {
  type    = bool
  default = true
}

variable "linux_monitoring_vm_application_security_group_keys" {
  description = "이 VM에만 적용할 ASG 키 목록. null이면 application_security_group_keys 사용. []면 미적용"
  type        = list(string)
  default     = null
}

variable "linux_monitoring_vm_extensions" {
  type = list(any)
  default = [
    {
      name                       = "AzureMonitorLinuxAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorLinuxAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings                   = {}
      protected_settings         = {}
    }
  ]
}

# --- Windows Example VM ---
variable "windows_example_vm_name" {
  type    = string
  default = "win-example"
}

variable "windows_example_vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "windows_example_admin_username" {
  type    = string
  default = "azureadmin"
}

variable "windows_example_admin_password" {
  type      = string
  sensitive = true
}

variable "windows_example_enable" {
  type    = bool
  default = true
}

variable "windows_example_application_security_group_keys" {
  description = "이 VM에만 적용할 ASG 키 목록. null이면 application_security_group_keys 사용. []면 미적용"
  type        = list(string)
  default     = null
}

variable "windows_example_vm_extensions" {
  type = list(any)
  default = [
    {
      name                       = "AzureMonitorWindowsAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorWindowsAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings                   = {}
      protected_settings         = {}
    }
  ]
}
