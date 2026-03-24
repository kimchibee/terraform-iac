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
  description = "true ?�면 Monitoring-VM-Subnet ????Route Table ?�결 (모니?�링 VM??Spoke�?가??UDR???�우?�면 true)"
  type        = bool
  default     = true
}

variable "spoke_vnet_cidr_fallback" {
  description = "vnet/spoke-vnet state ??address_space 가 ?�을 ??Spoke ?�??(?? 10.1.0.0/24)"
  type        = string
  default     = "10.1.0.0/24"
}

variable "enable_route_to_spoke_vnet" {
  description = "true ?�면 Spoke VNet �?address_prefix �?가??경로 1�??�동 추�?"
  type        = bool
  default     = false
}

variable "spoke_route_next_hop_type" {
  type    = string
  default = "VirtualAppliance"
}

variable "spoke_route_next_hop_ip" {
  type        = string
  default     = null
  description = "VirtualAppliance ????NVA IP"
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
