variable "name" {
  type = string
}

variable "resource_group_id" {
  type = string
}

variable "location" {
  type = string
}

variable "kind" {
  type    = string
  default = "OpenAI"
}

variable "sku_name" {
  type    = string
  default = "S0"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "public_network_access_enabled" {
  type    = bool
  default = true
}

variable "cognitive_deployments" {
  type = map(object({
    name = string
    model = object({
      format  = string
      name    = string
      version = optional(string)
    })
    scale = object({
      type     = string
      capacity = optional(number)
    })
  }))
  default = {}
}
