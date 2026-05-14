variable "hub_subscription_id" {
  description = "Azure subscription ID for the Hub side. The state backend will be created here."
  type        = string
}

variable "location" {
  description = "Azure region for the Hub state backend"
  type        = string
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "Resource group name for the Hub state backend"
  type        = string
  default     = "terraform-state-hub-rg"
}

variable "storage_account_name" {
  description = "Hub state storage account name (globally unique, 3-24 lowercase alphanumeric). Must match the value set in each Hub leaf's tfvars (hub_backend_storage_account_name)."
  type        = string
  default     = "tfstatehuba9911"
}

variable "container_name" {
  description = "Blob container name for Hub state files"
  type        = string
  default     = "tfstate"
}

variable "tags" {
  description = "Tags applied to Hub state RG and SA"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "tfstate"
    Side      = "hub"
  }
}

variable "enable_blob_versioning" {
  description = "Enable blob versioning to protect state from accidental overwrite"
  type        = bool
  default     = true
}
