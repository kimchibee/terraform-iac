variable "project_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "spoke_subscription_id" {
  type = string
}

variable "deploy_azure_firewall" {
  description = "When true, creates Azure Firewall policy resources."
  type        = bool
  default     = false
}

variable "firewall_subnet_id" {
  description = "Firewall subnet ID used when deploy_azure_firewall is true."
  type        = string
  default     = null
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier."
  type        = string
  default     = "Standard"
}

variable "firewall_zones" {
  description = "Availability zones for firewall resources."
  type        = list(string)
  default     = null
}

variable "firewall_public_ip_zones" {
  type    = list(string)
  default = null
}

variable "spoke_backend_resource_group_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "spoke_backend_storage_account_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage account 이름"
}

variable "spoke_backend_container_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage container 이름"
}
