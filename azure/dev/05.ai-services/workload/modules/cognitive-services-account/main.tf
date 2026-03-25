terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

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

module "avm" {
  source  = "Azure/avm-res-cognitiveservices-account/azurerm"
  version = "0.11.0"

  name                          = var.name
  parent_id                     = var.resource_group_id
  location                      = var.location
  kind                          = var.kind
  sku_name                      = var.sku_name
  cognitive_deployments         = var.cognitive_deployments
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
  enable_telemetry              = false
}

output "id" {
  value = module.avm.resource_id
}

output "name" {
  value = module.avm.name
}

output "endpoint" {
  value = module.avm.endpoint
}
