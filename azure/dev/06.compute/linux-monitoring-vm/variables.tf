#--------------------------------------------------------------
# Linux VM 모듈 변수
# 루트에서 전달: name_prefix, resource_group_name, subnet_id, location, tags, application_security_group_ids
# 이 폴더에서 관리(기본값): vm_name_suffix, vm_size, admin_username, ssh_private_key_filename, enable_vm, vm_extensions
# 폴더 복제 시 이 파일의 기본값만 수정하면 됨.
#--------------------------------------------------------------

# ---- 루트에서만 전달 (컨텍스트) ----
variable "name_prefix" {
  description = "리소스 이름 접두사 (루트에서 project_name 기반으로 전달)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "application_security_group_ids" {
  description = "NIC에 붙일 ASG ID 목록. 루트에서 network state 기반으로 전달"
  type        = list(string)
  default     = []
}

# ---- 이 폴더에서 관리 (리소스별 기본값, 복제 시 여기만 수정) ----
variable "vm_name_suffix" {
  description = "VM 이름 접미사. 최종 이름은 name_prefix-vm_name_suffix"
  type        = string
  default     = "monitoring-vm"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_private_key_filename" {
  description = "SSH 개인키 파일명 (compute 루트에 저장). .gitignore 대상"
  type        = string
  default     = "vm_key.pem"
}

variable "enable_vm" {
  type    = bool
  default = true
}

variable "vm_extensions" {
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
