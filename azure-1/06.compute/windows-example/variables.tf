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

variable "application_security_group_keys" {
  type    = list(string)
  default = ["keyvault_clients", "vm_allowed_clients"]
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "vm_name_suffix" {
  type    = string
  default = "win-example"
}

variable "vm_computer_name_suffix" {
  type    = string
  default = "winex"
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "enable_vm" {
  type    = bool
  default = true
}

variable "vm_extensions" {
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
