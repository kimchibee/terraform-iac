#--------------------------------------------------------------
# RBAC Stack
# - Monitoring VM(compute 스택) Managed Identity에 Hub/Spoke 리소스 접근 역할 부여
# - 시나리오 1: 관리자 그룹 / AI 개발자 그룹에 그룹 기반 리소스 권한 부여 (선택)
# compute → rbac 순서로 적용 (VM 생성 후 역할 부여)
#--------------------------------------------------------------
#
# [A-1] 그룹 기반 권한: 기존 Azure AD(Entra ID) 보안 그룹 사용. 그룹 Object ID를 변수로 입력.
#       멤버십은 각 그룹의 admin-users / ai-developer-users 하위 모듈에서 Terraform(azuread_group_member)으로 등록/변경/삭제.
#
#--------------------------------------------------------------
# Remote State: Compute (VM identity), Network, Storage, AI Services, APIM
#--------------------------------------------------------------
# Compute 루트 state 참조
data "terraform_remote_state" "compute" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/compute/terraform.tfstate"
  }
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/storage/terraform.tfstate"
  }
}

data "terraform_remote_state" "ai_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name  = var.backend_storage_account_name
    container_name        = var.backend_container_name
    key                   = "azure/dev/ai-services/terraform.tfstate"
  }
}

data "terraform_remote_state" "apim" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/apim/terraform.tfstate"
  }
}

locals {
  vm_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, null)
  enable_roles    = var.enable_monitoring_vm_roles && local.vm_principal_id != null

  # 시나리오 1: 관리자 그룹 / AI 개발자 그룹 역할 할당 여부
  enable_admin_group        = var.admin_group_object_id != null && var.admin_group_scope_id != null && trimspace(var.admin_group_object_id) != "" && trimspace(var.admin_group_scope_id) != ""
  enable_ai_developer_group = var.ai_developer_group_object_id != null && trimspace(var.ai_developer_group_object_id) != ""

  # 시나리오 2: 리소스별 IAM — scope_ref로 참조 가능한 리소스 ID (B-3)
  scope_refs = {
    "storage_key_vault_id"     = try(data.terraform_remote_state.storage.outputs.key_vault_id, "")
    "ai_services_openai_id"    = try(data.terraform_remote_state.ai_services.outputs.openai_id, "")
    "ai_services_key_vault_id" = try(data.terraform_remote_state.ai_services.outputs.key_vault_id, "")
    "ai_services_storage_id"   = try(data.terraform_remote_state.ai_services.outputs.storage_account_id, "")
    "network_hub_rg_id"        = try(data.terraform_remote_state.network.outputs.hub_resource_group_id, "")
    "network_spoke_rg_id"      = try(data.terraform_remote_state.network.outputs.spoke_resource_group_id, "")
    "apim_id"                  = try(data.terraform_remote_state.apim.outputs.apim_id, "") # APIM은 Spoke 구독. iam_role_assignments 시 use_spoke_provider = true
  }

  iam_role_assignments_resolved = [
    for r in var.iam_role_assignments : merge(r, {
      scope = (r.scope_ref != null && trimspace(r.scope_ref) != "") ? try(local.scope_refs[r.scope_ref], "") : (r.scope != null ? r.scope : "")
    })
  ]
  iam_role_assignments_valid = [for r in local.iam_role_assignments_resolved : r if r.scope != null && trimspace(r.scope) != ""]
  iam_for_hub                = { for r in local.iam_role_assignments_valid : sha256("${r.principal_id}${r.scope}${r.role_definition_name}") => r if !r.use_spoke_provider }
  iam_for_spoke              = { for r in local.iam_role_assignments_valid : sha256("${r.principal_id}${r.scope}${r.role_definition_name}") => r if r.use_spoke_provider }
}

#--------------------------------------------------------------
# 시나리오 1: 그룹 기반 권한 — 폴더 단위 모듈 호출
# 각 그룹별 디렉터리(admin-group, ai-developer-group 등)가 모듈이며,
# 신규 그룹 추가 시 동일 구조의 폴더를 복제한 뒤 루트에 module 블록·변수 추가.
#--------------------------------------------------------------
module "admin_group" {
  count  = local.enable_admin_group ? 1 : 0
  source = "./admin-group"

  providers = {
    azurerm = azurerm.hub
    azuread = azuread
  }

  group_object_id   = var.admin_group_object_id
  scope_id          = var.admin_group_scope_id
  member_object_ids = coalesce(var.admin_group_member_object_ids, [])
}

module "ai_developer_group" {
  count  = local.enable_ai_developer_group ? 1 : 0
  source = "./ai-developer-group"

  providers = {
    azurerm = azurerm.spoke
    azuread = azuread
  }

  group_object_id         = var.ai_developer_group_object_id
  spoke_resource_group_id = data.terraform_remote_state.network.outputs.spoke_resource_group_id
  openai_id               = try(data.terraform_remote_state.ai_services.outputs.openai_id, null)
  member_object_ids       = coalesce(var.ai_developer_group_member_object_ids, [])
}

#--------------------------------------------------------------
# 시나리오 2: 리소스별 IAM 역할 할당 (변수 기반) — B-3
# iam_role_assignments 목록에 정의된 (principal, scope, role)만큼 역할 부여.
# 추가/변경/삭제 시 terraform.tfvars의 iam_role_assignments만 수정 후 plan/apply.
#--------------------------------------------------------------
resource "azurerm_role_assignment" "resource_iam_hub" {
  for_each = local.iam_for_hub

  provider = azurerm.hub

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

resource "azurerm_role_assignment" "resource_iam_spoke" {
  for_each = local.iam_for_spoke

  provider = azurerm.spoke

  scope                = each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Storage Accounts (Blob Data Contributor)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = local.enable_roles && length(try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {})) > 0 ? try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids, {}) : {}

  provider = azurerm.hub

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Key Vault (Secrets User, Reader)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = local.enable_roles && var.enable_key_vault_roles && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Reader"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Hub: Monitoring VM → Hub Resource Group (Reader)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_reader" {
  count = local.enable_roles ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.network.outputs.hub_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}

#--------------------------------------------------------------
# Spoke: Monitoring VM → Spoke Key Vault, Storage, OpenAI, RG
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_spoke_key_vault_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.key_vault_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_storage_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.storage_account_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_access" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_openai_reader" {
  count = local.enable_roles && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.ai_services.outputs.openai_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}

resource "azurerm_role_assignment" "vm_spoke_reader" {
  count = local.enable_roles ? 1 : 0

  provider = azurerm.spoke

  scope                = data.terraform_remote_state.network.outputs.spoke_resource_group_id
  role_definition_name = "Reader"
  principal_id         = local.vm_principal_id
}
