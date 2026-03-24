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
  description = "false�?Firewall Policy�??�성 (방화�?VM/PIP ?�음)"
  type        = bool
  default     = true
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Standard 권장; Policy sku?� 맞출 �?"
  type        = string
  default     = "Standard"
}

variable "firewall_zones" {
  description = "가???�역 (리전???�라 null)"
  type        = list(string)
  default     = null
}

variable "firewall_public_ip_zones" {
  type    = list(string)
  default = null
}
