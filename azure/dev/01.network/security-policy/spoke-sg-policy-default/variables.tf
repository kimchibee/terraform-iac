variable "project_name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
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

variable "deploy_azure_firewall" {
  description = "false�?Firewall Policy�??�성. true�?vnet/spoke-vnet state??firewall_subnet_key ?�브?�이 ?�어????
  type        = bool
  default     = false
}

variable "firewall_subnet_id" {
  description = "deploy_azure_firewall=true ?????�용??Azure Firewall subnet ID"
  type        = string
  default     = null
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Policy sku?� 맞출 �?"
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
