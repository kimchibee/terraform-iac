#--------------------------------------------------------------
# Bootstrap Backend Variables
#--------------------------------------------------------------

variable "resource_group_name" {
  description = "Resource group name for backend storage"
  type        = string
}

# 전역 고유 리소스: Azure Storage 계정 이름은 Azure 전체(모든 고객·구독)에서 유일해야 함.
# 규칙: 소문자·숫자만, 3~24자, 하이픈 불가. 레포 사용 시 반드시 본인만의 고유명으로 수정 필요.
variable "storage_account_name" {
  description = "Storage account name for Terraform state. GLOBALLY UNIQUE across Azure (lowercase + digits only, 3-24 chars, no hyphens). Change to your own unique name when using this repo."
  type        = string
}

variable "container_name" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "location" {
  description = "Azure region for backend resources"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for Private Endpoint (optional)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to backend resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "Terraform-Backend"
  }
}
