#--------------------------------------------------------------
# Linux VM 모듈 변수 (compute 루트에서 전달)
#--------------------------------------------------------------

variable "resource_group_name" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "location" {
  type = string
}

variable "vm_name" {
  description = "VM 리소스 이름 (전체, 예: project-x-x-monitoring-vm)"
  type        = string
}

variable "vm_size" {
  type    = string
  default = "Standard_D2s_v3"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vm_extensions" {
  type    = list(any)
  default = []
}

variable "ssh_private_key_filename" {
  description = "PEM 파일명 (compute 루트에 저장). .gitignore 대상"
  type        = string
  default     = "vm_key.pem"
}

variable "enable_vm" {
  type    = bool
  default = true
}

# Network 스택 방화벽 정책(ASG): Key Vault 접근 허용(keyvault_clients_asg_id), VM 접속 허용(vm_allowed_clients_asg_id) 등
variable "application_security_group_ids" {
  description = "이 VM NIC에 붙일 Application Security Group ID 목록. network 스택 output(keyvault_clients_asg_id, vm_allowed_clients_asg_id)에서 전달"
  type        = list(string)
  default     = []
}
