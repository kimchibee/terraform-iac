variable "subscription_id" {
  description = "Azure subscription ID where the Terraform state backend will be created"
  type        = string
}

variable "location" {
  description = "Azure region for the state backend resource group and storage account"
  type        = string
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "Resource group name for the state backend"
  type        = string
  default     = "terraform-state-rg"
}

variable "storage_account_name" {
  description = "Storage account name (globally unique, 3-24 lowercase alphanumeric). Must match scripts/import/env.sh TF_BACKEND_SA."
  type        = string
  default     = "tfstatea9911"
}

variable "container_name" {
  description = "Blob container name for state files"
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to resource group and storage account"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "tfstate"
  }
}

variable "enable_blob_versioning" {
  description = "Enable blob versioning on the storage account to protect state from accidental overwrite"
  type        = bool
  default     = true
}
