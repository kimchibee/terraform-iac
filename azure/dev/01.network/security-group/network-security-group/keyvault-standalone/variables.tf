variable "project_name" {
  type = string
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

variable "tags" {
  type    = map(string)
  default = {}
}

variable "enabled" {
  type    = bool
  default = true
}

variable "nsg_name" {
  type    = string
  default = ""
}
