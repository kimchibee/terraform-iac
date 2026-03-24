variable "project_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "hub_subscription_id" {
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

variable "deploy_azure_firewall" {
  description = "If false, only firewall policy is created (no Azure Firewall/PIP resources)."
  type        = bool
  default     = true
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier. Keep this aligned with the firewall policy SKU."
  type        = string
  default     = "Standard"
}

variable "firewall_zones" {
  description = "Optional availability zones. Set null if zones are not supported in region."
  type        = list(string)
  default     = null
}

variable "firewall_public_ip_zones" {
  type    = list(string)
  default = null
}
