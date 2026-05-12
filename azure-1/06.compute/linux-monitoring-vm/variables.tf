#--------------------------------------------------------------
# Linux Monitoring VM leaf variables
# (uses network remote state for Hub RG/subnet/ASG references)
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

variable "application_security_group_keys" {
  description = "ASG keys to attach to the VM NIC (resolved from network state outputs)."
  type        = list(string)
  default     = ["keyvault_clients", "vm_allowed_clients"]
}

# ---- VM defaults (override in terraform.tfvars if needed) ----
variable "vm_name_suffix" {
  type    = string
  default = "monitoring-vm"
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
  type    = string
  default = "vm_key.pem"
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
