variable "spoke_subscription_id" {
  description = "Azure subscription ID for the Spoke side. The state backend will be created here."
  type        = string
}

variable "location" {
  description = "Azure region for the Spoke state backend"
  type        = string
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "Resource group name for the Spoke state backend"
  type        = string
  default     = "terraform-state-spoke-rg"
}

variable "storage_account_name" {
  description = "Spoke state storage account name (globally unique, 3-24 lowercase alphanumeric). Must match the value set in each Spoke leaf's tfvars (spoke_backend_storage_account_name)."
  type        = string
  default     = "tfstatespka9911"
}

variable "container_name" {
  description = "Blob container name for Spoke state files"
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to Spoke state RG and SA"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "tfstate"
    Side      = "spoke"
  }
}

variable "enable_blob_versioning" {
  description = "Enable blob versioning to protect state from accidental overwrite"
  type        = bool
  default     = true
}
