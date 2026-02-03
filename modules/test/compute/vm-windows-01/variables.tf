#--------------------------------------------------------------
# Windows VM Instance Variables
#--------------------------------------------------------------

variable "vm_name" {
  description = "VM 이름"
  type        = string
}

variable "vm_size" {
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

variable "vnet_name" {
  description = "Virtual Network 이름"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Virtual Network가 속한 Resource Group 이름"
  type        = string
}

variable "subnet_name" {
  description = "서브넷 이름 (예: snet-app, snet-database, snet-web 등)"
  type        = string
}

variable "admin_username" {
  description = "관리자 사용자명"
  type        = string
}

variable "admin_password" {
  description = "관리자 비밀번호 (Windows 필수)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "리소스 태그"
  type        = map(string)
  default     = {}
}

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
