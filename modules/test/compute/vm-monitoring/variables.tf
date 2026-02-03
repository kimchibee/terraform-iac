#--------------------------------------------------------------
# Monitoring VM Instance Variables
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
  description = "서브넷 이름 (예: Monitoring-VM-Subnet, snet-app, snet-database 등)"
  type        = string
}

variable "admin_username" {
  description = "관리자 사용자명"
  type        = string
}

variable "admin_password" {
  description = "관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "admin_ssh_keys" {
  description = "SSH 공개키 목록 (선택사항, 비밀번호 대신 사용 가능)"
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
  default = [
    {
      name                       = "AzureMonitorLinuxAgent"
      publisher                  = "Microsoft.Azure.Monitor"
      type                       = "AzureMonitorLinuxAgent"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings                   = {}
      protected_settings         = {}
    },
    {
      name                       = "enablevmAccess"
      publisher                  = "Microsoft.Azure.Security"
      type                       = "AzureDiskEncryptionForLinux"
      type_handler_version       = "1.0"
      auto_upgrade_minor_version = true
      settings                   = {}
      protected_settings         = {}
    }
  ]
}
