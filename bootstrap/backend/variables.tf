#--------------------------------------------------------------
# Bootstrap Backend Variables
#--------------------------------------------------------------

variable "resource_group_name" {
  description = "Resource group name for backend storage"
  type        = string
}

variable "storage_account_name" {
  description = "Storage account name for Terraform state (must be globally unique, lowercase, alphanumeric)"
  type        = string
}

variable "container_name" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "location" {
  description = "Azure region for backend resources"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Private Endpoint (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to backend resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "Terraform-Backend"
  }
}
