#--------------------------------------------------------------
# VM Module Variables
# 공통 VM 모듈의 입력 변수 정의
#--------------------------------------------------------------

variable "name" {
  description = "VM 이름"
  type        = string
}

variable "os_type" {
  description = "OS 타입 (linux 또는 windows)"
  type        = string
  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "os_type은 'linux' 또는 'windows'여야 합니다."
  }
}

variable "size" {
  description = "VM 크기"
  type        = string
  default     = "Standard_B2s"
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group 이름"
  type        = string
}

variable "subnet_id" {
  description = "서브넷 ID"
  type        = string
}

variable "admin_username" {
  description = "관리자 사용자명"
  type        = string
}

variable "admin_password" {
  description = "관리자 비밀번호 (Windows용, Linux는 선택사항)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "admin_ssh_keys" {
  description = "SSH 공개키 목록 (Linux용)"
  type = list(object({
    username   = string
    public_key = string
  }))
  default = []
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

# Linux VM 전용 변수
variable "linux_image" {
  description = "Linux 이미지 설정"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}

# Windows VM 전용 변수
variable "windows_image" {
  description = "Windows 이미지 설정"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

variable "os_disk" {
  description = "OS 디스크 설정"
  type = object({
    caching              = string
    storage_account_type = string
    disk_size_gb         = number
  })
  default = {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }
}

variable "enable_identity" {
  description = "System Assigned Managed Identity 활성화"
  type        = bool
  default     = true
}

variable "enable_boot_diagnostics" {
  description = "Boot Diagnostics 활성화"
  type        = bool
  default     = false
}

variable "boot_diagnostics_storage_account_uri" {
  description = "Boot Diagnostics Storage Account URI"
  type        = string
  default     = null
}

variable "vm_extensions" {
  description = "VM Extension 목록"
  type = list(object({
    name                       = string
    publisher                  = string
    type                       = string
    type_handler_version       = string
    auto_upgrade_minor_version = bool
    settings                   = optional(map(string), {})
    protected_settings         = optional(map(string), {})
  }))
  default = []
}
