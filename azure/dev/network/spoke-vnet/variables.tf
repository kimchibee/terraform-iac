variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "tags" { type = map(string) }
variable "resource_group_name" { type = string }
variable "vnet_name" { type = string }
variable "vnet_address_space" { type = list(string) }
variable "subnets" { type = map(any) }
variable "hub_vnet_id" { type = string }
variable "hub_resource_group_name" { type = string }
variable "private_dns_zone_ids" { type = map(string) }
variable "spoke_private_dns_zones" {
  type    = map(string)
  default = {}
}
