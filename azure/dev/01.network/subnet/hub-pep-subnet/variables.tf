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

variable "use_securitygroup_prereq" {
  description = "Use security group and ASG remote-state prerequisites when true."
  type        = bool
  default     = false
}

# ?�나리오 3: keyvault-sg
variable "enable_keyvault_sg" {
  description = "Enable key-vault outbound NSG policy integration."
  type        = bool
  default     = false
}

variable "hub_subnet_names_attach_keyvault_sg" {
  description = "Hub subnet names to associate with key vault standalone NSG."
  type        = list(string)
  default     = []
}

variable "hub_nsg_keys_add_keyvault_rule" {
  description = "Hub NSG keys where key vault outbound rules are injected."
  type        = list(string)
  default     = []
}

variable "enable_pe_inbound_from_asg" {
  description = "Enable inbound 443 PE rule from keyvault-clients ASG."
  type        = bool
  default     = false
}

variable "keyvault_clients_asg_name" {
  type    = string
  default = "keyvault-clients-asg"
}

# VM ?�근 ASG
variable "enable_vm_access_sg" {
  type    = bool
  default = false
}

variable "vm_allowed_clients_asg_name" {
  type    = string
  default = "vm-allowed-clients-asg"
}

variable "vm_access_target_nsg_keys" {
  type    = list(string)
  default = []
}

variable "vm_access_target_nsg_ids_extra" {
  type    = list(string)
  default = []
}

variable "vm_access_destination_ports" {
  type    = list(string)
  default = ["22", "3389"]
}
