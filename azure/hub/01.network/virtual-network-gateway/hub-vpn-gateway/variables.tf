variable "project_name" { type = string }

variable "location" { type = string }

variable "tags" {
  type = map(string)
  default = {}
}

variable "hub_subscription_id" { type = string }

variable "vpn_gateway_sku" {
  type    = string
  default = "VpnGw1"
}

variable "vpn_gateway_type" {
  type    = string
  default = "Vpn"
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
