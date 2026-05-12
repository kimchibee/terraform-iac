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

variable "enable_openai_egress_rule" {
  description = "Create firewall policy rule to allow monitoring subnet egress to Azure OpenAI over HTTPS."
  type        = bool
  default     = true
}

variable "monitoring_subnet_cidrs" {
  description = "Source CIDRs for monitoring VM subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "openai_destination_fqdns" {
  description = "Destination FQDN patterns for Azure OpenAI calls through firewall."
  type        = list(string)
  default     = ["*.openai.azure.com"]
}

variable "hub_backend_resource_group_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "hub_backend_storage_account_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage account 이름"
}

variable "hub_backend_container_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage container 이름"
}
