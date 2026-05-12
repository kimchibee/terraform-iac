variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "location" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
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

variable "bgp_route_propagation_enabled" {
  type    = bool
  default = true
}

variable "associate_route_table_to_monitoring_subnet" {
  description = "Attach route table to Monitoring-VM-Subnet when true."
  type        = bool
  default     = true
}

variable "spoke_vnet_cidr_fallback" {
  description = "Fallback Spoke CIDR when remote state address space is unavailable."
  type        = string
  default     = "10.1.0.0/24"
}

variable "enable_route_to_spoke_vnet" {
  description = "Automatically add one route to Spoke VNet CIDR when true."
  type        = bool
  default     = true
}

variable "spoke_route_next_hop_type" {
  type    = string
  default = "VirtualAppliance"
}

variable "spoke_route_next_hop_ip" {
  type        = string
  default     = null
  description = "Next-hop IP when `spoke_route_next_hop_type` is `VirtualAppliance`. If null, fallback to hub firewall private IP from security-policy state."
}

variable "custom_routes" {
  type = list(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = []
}
