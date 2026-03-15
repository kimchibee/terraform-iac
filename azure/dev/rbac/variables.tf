#--------------------------------------------------------------
# RBAC Stack Variables
#--------------------------------------------------------------

variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Tags for role assignments (metadata)"
  type        = map(string)
  default     = {}
}

variable "hub_subscription_id" {
  description = "Hub subscription ID"
  type        = string
}

variable "spoke_subscription_id" {
  description = "Spoke subscription ID"
  type        = string
}

variable "backend_resource_group_name" {
  description = "Backend storage resource group (for remote_state)"
  type        = string
}

variable "backend_storage_account_name" {
  description = "Backend storage account name"
  type        = string
}

variable "backend_container_name" {
  description = "Backend container name"
  type        = string
  default     = "tfstate"
}

# compute 스택에서 Monitoring VM을 사용할 때만 역할 부여
variable "enable_monitoring_vm_roles" {
  description = "Monitoring VM에 Hub/Spoke 리소스 접근 역할 부여 (compute 스택에서 VM 사용 시 true)"
  type        = bool
  default     = true
}

variable "enable_key_vault_roles" {
  description = "Hub Key Vault 관련 역할 부여 (storage 스택에 Key Vault 있을 때 true)"
  type        = bool
  default     = true
}

#--------------------------------------------------------------
# 시나리오 1: 관리자 그룹 (그룹 기반 리소스 권한)
# 기존 Azure AD 보안 그룹 Object ID 입력. 멤버십은 AD 포털 등에서 관리.
#--------------------------------------------------------------
variable "admin_group_object_id" {
  description = "관리자 그룹 Azure AD Object ID. 설정 시 해당 그룹에 admin_group_scope_id 범위로 역할 부여. null이면 역할 할당 안 함."
  type        = string
  default     = null
}

variable "admin_group_scope_id" {
  description = "관리자 그룹에 부여할 역할의 scope (ARM 리소스 ID). 예: 구독 /subscriptions/{id}, 리소스 그룹 ID 등."
  type        = string
  default     = null
}

variable "admin_group_role_definition_name" {
  description = "관리자 그룹에 부여할 역할 이름 (예: Contributor, Owner)"
  type        = string
  default     = "Contributor"
}

variable "admin_group_member_object_ids" {
  description = "관리자 그룹에 소속시킬 멤버의 Azure AD Object ID 목록 (사용자·그룹·서비스 주체). 등록/변경/삭제는 Terraform apply로 반영."
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# 시나리오 1: AI 개발자 그룹 (AI 관련 서비스만 접근)
# 기존 Azure AD 보안 그룹 Object ID 입력. scope는 Spoke/AI 리소스로 제한.
#--------------------------------------------------------------
variable "ai_developer_group_object_id" {
  description = "AI 개발자 그룹 Azure AD Object ID. 설정 시 Spoke RG, OpenAI 등에 역할 부여. null이면 역할 할당 안 함."
  type        = string
  default     = null
}

variable "ai_developer_group_spoke_rg_role" {
  description = "AI 개발자 그룹에 부여할 Spoke 리소스 그룹 역할 (예: Reader)"
  type        = string
  default     = "Reader"
}

variable "ai_developer_group_member_object_ids" {
  description = "AI 개발자 그룹에 소속시킬 멤버의 Azure AD Object ID 목록. 등록/변경/삭제는 Terraform apply로 반영."
  type        = list(string)
  default     = []
}

#--------------------------------------------------------------
# 시나리오 2: 리소스별 IAM(역할) Terraform 관리 (B-1, B-2)
# identity별·리소스별 역할 매핑을 변수로 정의. 추가/변경/삭제 시 목록만 수정 후 plan/apply.
#
# [대상 리소스·역할 예시]
# - Key Vault: Key Vault Secrets User, Key Vault Reader (scope_ref: storage_key_vault_id, ai_services_key_vault_id)
# - Storage: Storage Blob Data Contributor (scope_ref: storage_monitoring_sa_* 또는 ai_services_storage_id)
# - OpenAI: Cognitive Services User, Reader (scope_ref: ai_services_openai_id)
# - APIM(Spoke 구독): API Management Service Contributor Role 등 (scope_ref: apim_id, use_spoke_provider=true 필수)
# - RG: Reader, Contributor (scope_ref: network_hub_rg_id, network_spoke_rg_id)
# scope_ref 미지원 리소스는 scope에 ARM 리소스 ID 전체 입력.
#--------------------------------------------------------------
variable "iam_role_assignments" {
  description = "리소스별 IAM 역할 할당 목록. principal_id(사용자·그룹·Managed Identity 등)에 scope(또는 scope_ref) 범위로 역할 부여. 추가/변경/삭제 시 이 목록만 수정 후 apply."
  type = list(object({
    principal_id         = string
    role_definition_name = string
    use_spoke_provider   = optional(bool, false) # true면 Spoke 구독, false면 Hub 구독
    scope_ref            = optional(string)     # 아래 scope_ref 목록 중 하나. 비우면 scope 사용
    scope                = optional(string)     # scope_ref 미사용 시 ARM 리소스 ID 전체
  }))
  default = []
}
