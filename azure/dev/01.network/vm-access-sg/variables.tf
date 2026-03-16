#--------------------------------------------------------------
# vm-access-sg 모듈 변수
#--------------------------------------------------------------

variable "resource_group_name" {
  description = "Resource group name for the ASG (Hub RG 권장)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "enable_vm_access_sg" {
  description = "VM 접근 허용용 ASG + 타겟 NSG 인바운드 규칙 생성 여부"
  type        = bool
  default     = false
}

variable "vm_allowed_clients_asg_name" {
  description = "VM 접속을 허용할 클라이언트용 ASG 이름"
  type        = string
  default     = "vm-allowed-clients-asg"
}

# 타겟 VM이 속한 서브넷(또는 VM)에 붙은 NSG의 ARM ID 목록 (Hub 구독)
variable "target_nsg_ids" {
  description = "타겟 VM을 보호하는 Hub NSG ID 목록. 이 NSG들에 인바운드(소스=ASG, 포트) 규칙 추가"
  type        = list(string)
  default     = []
}


variable "destination_ports" {
  description = "허용할 목적지 포트 (예: 22=SSH, 3389=RDP, 443=HTTPS)"
  type        = list(string)
  default     = ["22", "3389"]
}
