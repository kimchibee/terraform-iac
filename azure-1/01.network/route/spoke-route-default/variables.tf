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

variable "spoke_subscription_id" {
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
  description = "Enable BGP route propagation on the route table."
  type        = bool
  default     = true
}

variable "hub_monitoring_subnet_key" {
  description = "Key of the monitoring subnet in hub subnet map."
  type        = string
  default     = "Monitoring-VM-Subnet"
}

variable "hub_monitoring_subnet_cidr_fallback" {
  description = "Fallback CIDR when monitoring subnet output is unavailable."
  type        = string
  default     = "10.0.1.0/24"
}

variable "enable_route_to_hub_monitoring" {
  description = "Create an extra route to monitoring subnet when enabled."
  type        = bool
  default     = false
}

variable "hub_monitoring_route_next_hop_type" {
  description = "Next hop type used for monitoring subnet route."
  type        = string
  default     = "VirtualAppliance"
}

variable "hub_monitoring_route_next_hop_ip" {
  description = "Next hop IP when next_hop_type is VirtualAppliance."
  type        = string
  default     = null
}

variable "custom_routes" {
  description = "Additional custom routes to append."
  type = list(object({
    name                   = string
    address_prefix         = string
    next_hop_type          = string
    next_hop_in_ip_address = optional(string)
  }))
  default = []
}

variable "spoke_subnet_keys_for_route_table" {
  description = "Spoke subnet keys to associate with this route table."
  type        = list(string)
  default     = ["apim-snet", "pep-snet"]
}
