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
  type = map(string)
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
  description = "true�?01.network ??application-security-group / network-security-group 리프 state?�서 ID�??�어 규칙·?�결�??�용"
  type        = bool
  default     = false
}

# ?�나리오 3: keyvault-sg
variable "enable_keyvault_sg" {
  description = "Enable keyvault-sg: NSG 규칙?�로 Key Vault(443) ?�웃바운???�용"
  type        = bool
  default     = false
}

variable "hub_subnet_names_attach_keyvault_sg" {
  description = "Hub ?�브???�름 목록: standalone keyvault-sg NSG�??�결???�브??
  type        = list(string)
  default     = []
}

variable "hub_nsg_keys_add_keyvault_rule" {
  description = "Key Vault ?�웃바운??규칙??추�???Hub NSG ?? monitoring_vm, pep"
  type        = list(string)
  default     = []
}

variable "enable_pe_inbound_from_asg" {
  description = "PE(pep-snet) NSG???�바?�드: ?�스=keyvault-clients ASG, ?�트 443"
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
