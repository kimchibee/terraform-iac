#--------------------------------------------------------------
# Compute Stack
# Monitoring VM과 관련 Role Assignments를 관리하는 스택
# AWS 방식: network, storage 스택의 remote_state를 읽어서 의존성 해결
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Storage Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/storage/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# AI Services Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "ai_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/ai-services/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Monitoring VM (공통 모듈 virtual-machine)
#--------------------------------------------------------------
module "monitoring_vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_monitoring_vm ? 1 : 0

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_vm_name
  os_type             = "linux"
  size                = var.vm_size
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_id           = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  tags                = var.tags
  enable_identity      = true
  vm_extensions = [
    { name = "AzureMonitorLinuxAgent", publisher = "Microsoft.Azure.Monitor", type = "AzureMonitorLinuxAgent", type_handler_version = "1.0", auto_upgrade_minor_version = true, settings = {}, protected_settings = {} },
    { name = "enablevmAccess", publisher = "Microsoft.Azure.Security", type = "AzureDiskEncryptionForLinux", type_handler_version = "1.0", auto_upgrade_minor_version = true, settings = {}, protected_settings = {} }
  ]
}

#--------------------------------------------------------------
# Role Assignments: Monitoring VM → Storage Accounts & Key Vault
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = var.enable_monitoring_vm && length(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids) > 0 ? {
    for name, account_id in data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids : name => account_id
  } : {}

  provider = azurerm.hub

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = var.enable_monitoring_vm && var.enable_key_vault && data.terraform_remote_state.storage.outputs.key_vault_id != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = var.enable_monitoring_vm && var.enable_key_vault && data.terraform_remote_state.storage.outputs.key_vault_id != null ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name = "Key Vault Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

resource "azurerm_role_assignment" "vm_storage_reader" {
  count = var.enable_monitoring_vm ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.network.outputs.hub_resource_group_id
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

#--------------------------------------------------------------
# Role Assignments: Hub VM → Spoke Resources
#--------------------------------------------------------------
# Spoke Key Vault: Key Vault Secrets User (AI Foundry용 - ai-services 스택에서 관리)
resource "azurerm_role_assignment" "vm_spoke_key_vault_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm && try(data.terraform_remote_state.ai_services.outputs.key_vault_id, null) != null ? 1 : 0

  scope                = try(data.terraform_remote_state.ai_services.outputs.key_vault_id, "")
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# Spoke Storage Account: Storage Blob Data Contributor (AI Foundry용 - ai-services 스택에서 관리)
resource "azurerm_role_assignment" "vm_spoke_storage_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm && try(data.terraform_remote_state.ai_services.outputs.storage_account_id, null) != null ? 1 : 0

  scope                = try(data.terraform_remote_state.ai_services.outputs.storage_account_id, "")
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# OpenAI: Cognitive Services User (ai-services 스택에서 관리)
resource "azurerm_role_assignment" "vm_openai_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  scope                = try(data.terraform_remote_state.ai_services.outputs.openai_id, "")
  role_definition_name = "Cognitive Services User"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# OpenAI: Reader (ai-services 스택에서 관리)
resource "azurerm_role_assignment" "vm_openai_reader" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm && try(data.terraform_remote_state.ai_services.outputs.openai_id, null) != null ? 1 : 0

  scope                = try(data.terraform_remote_state.ai_services.outputs.openai_id, "")
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# Spoke Resource Group: Reader
resource "azurerm_role_assignment" "vm_spoke_reader" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = data.terraform_remote_state.network.outputs.spoke_resource_group_id
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}
