variable "tags" {
  type    = map(string)
  default = {}
}

variable "spoke_subscription_id" { type = string }

variable "backend_resource_group_name" { type = string }

variable "backend_storage_account_name" { type = string }

variable "backend_container_name" {
  type    = string
  default = "tfstate"
}
