variable "project_name" { type = string }

variable "location" { type = string }

variable "tags" {
  type = map(string)
  default = {}
}

variable "hub_subscription_id" { type = string }

variable "backend_resource_group_name" { type = string }

variable "backend_storage_account_name" { type = string }

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}

variable "vpn_gateway_sku" {
  type    = string
  default = "VpnGw1"
}

variable "vpn_gateway_type" {
  type    = string
  default = "Vpn"
}
