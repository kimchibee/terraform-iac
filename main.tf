#--------------------------------------------------------------
# 공통 모듈 저장소 지정
# - 공통 모듈(terraform-modules) 레포 주소. 새 모듈 추가 시 source에 아래 URL 사용.
# - 예: source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=v1.0.0"
# - 각 환경에 맞추어 수정 시: 아래 URL을 해당 환경의 terraform-modules 레포 주소로 변경할 것.
#   (main.tf 내 모든 module 블록의 source 중 git::...terraform-modules... 부분을 검색·일괄 변경)
#--------------------------------------------------------------
# 공통 모듈 저장소 URL (각 환경에 맞추어 수정)
# https://github.com/kimchibee/terraform-modules.git

#--------------------------------------------------------------
# Hub VNet Module (Created first - creates resource group)
#--------------------------------------------------------------
module "hub_vnet" {
  source = "./modules/dev/hub/vnet"

  providers = {
    azurerm = azurerm.hub
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group
  resource_group_name = local.hub_resource_group_name

  # Virtual Network
  vnet_name          = local.hub_vnet_name
  vnet_address_space = var.hub_vnet_address_space
  subnets            = var.hub_subnets

  # VPN Gateway
  vpn_gateway_name      = local.hub_vpn_gateway_name
  vpn_gateway_sku       = var.vpn_gateway_sku
  vpn_gateway_type      = var.vpn_gateway_type
  local_gateway_configs = var.local_gateway_configs
  vpn_shared_key        = var.vpn_shared_key

  # DNS Private Resolver
  dns_resolver_name = local.hub_dns_resolver_name

  # Key Vault
  key_vault_name = local.hub_key_vault_name

  # Log Analytics (will be set after shared module)
  log_analytics_workspace_id = ""

  # Feature Flags
  enable_key_vault              = var.enable_key_vault
  enable_dns_forwarding_ruleset = var.enable_dns_forwarding_ruleset
}

#--------------------------------------------------------------
# Log Analytics Workspace (공통 모듈)
#--------------------------------------------------------------
module "log_analytics_workspace" {
  source = "./terraform_modules/log-analytics-workspace"

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_log_analytics_name
  location             = var.location
  resource_group_name  = module.hub_vnet.resource_group_name
  retention_in_days    = var.log_analytics_retention_days
  tags                 = var.tags

  depends_on = [module.hub_vnet]
}

#--------------------------------------------------------------
# Shared Services: Solutions / Action Group / Dashboard (IaC 모듈)
#--------------------------------------------------------------
module "shared_services" {
  source = "./modules/dev/hub/shared-services"

  providers = {
    azurerm = azurerm.hub
  }

  enable                      = var.enable_shared_services
  resource_group_name         = module.hub_vnet.resource_group_name
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_workspace_name = module.log_analytics_workspace.name
  project_name                 = var.project_name
  location                     = var.location
  tags                         = var.tags

  depends_on = [module.log_analytics_workspace, module.hub_vnet]
}

#--------------------------------------------------------------
# Storage Module (Key Vault & Monitoring Storage)
#--------------------------------------------------------------
module "storage" {
  source = "./modules/dev/hub/monitoring-storage"

  providers = {
    azurerm = azurerm.hub
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group (from Hub module)
  resource_group_name = module.hub_vnet.resource_group_name
  key_vault_name      = local.hub_key_vault_name

  # Subnet IDs (from Hub module)
  monitoring_vm_subnet_id = module.hub_vnet.subnet_ids["Monitoring-VM-Subnet"]
  pep_subnet_id           = module.hub_vnet.subnet_ids["pep-snet"]

  # Private DNS Zones (from Hub module)
  private_dns_zone_ids = module.hub_vnet.private_dns_zone_ids

  # Feature Flags
  enable_key_vault = var.enable_key_vault

  depends_on = [module.hub_vnet]
}

#--------------------------------------------------------------
# Monitoring VM (공통 모듈 virtual-machine)
#--------------------------------------------------------------
module "monitoring_vm" {
  source = "./terraform_modules/virtual-machine"
  count  = var.enable_monitoring_vm ? 1 : 0

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.hub_vm_name
  os_type             = "linux"
  size                = var.vm_size
  location             = var.location
  resource_group_name  = module.hub_vnet.resource_group_name
  subnet_id            = module.hub_vnet.subnet_ids["Monitoring-VM-Subnet"]
  admin_username       = var.vm_admin_username
  admin_password       = var.vm_admin_password
  tags                 = var.tags
  enable_identity      = true
  vm_extensions = [
    { name = "AzureMonitorLinuxAgent", publisher = "Microsoft.Azure.Monitor", type = "AzureMonitorLinuxAgent", type_handler_version = "1.0", auto_upgrade_minor_version = true, settings = {}, protected_settings = {} },
    { name = "enablevmAccess", publisher = "Microsoft.Azure.Security", type = "AzureDiskEncryptionForLinux", type_handler_version = "1.0", auto_upgrade_minor_version = true, settings = {}, protected_settings = {} }
  ]

  depends_on = [module.hub_vnet]
}

#--------------------------------------------------------------
# Storage Module Role Assignments 업데이트
# Monitoring VM Identity를 Storage Module에 전달하기 위한 별도 리소스
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_access" {
  for_each = var.enable_monitoring_vm ? {
    for name, account_id in module.storage.monitoring_storage_account_ids : name => account_id
  } : {}

  provider = azurerm.hub

  scope                = each.value
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.monitoring_vm[0].identity_principal_id

  depends_on = [module.monitoring_vm, module.storage]
}

resource "azurerm_role_assignment" "vm_key_vault_access" {
  count = var.enable_monitoring_vm && var.enable_key_vault ? 1 : 0

  provider = azurerm.hub

  scope                = module.storage.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.monitoring_vm[0].identity_principal_id

  depends_on = [module.monitoring_vm, module.storage]
}

resource "azurerm_role_assignment" "vm_key_vault_reader" {
  count = var.enable_monitoring_vm && var.enable_key_vault ? 1 : 0

  provider = azurerm.hub

  scope                = module.storage.key_vault_id
  role_definition_name = "Key Vault Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id

  depends_on = [module.monitoring_vm, module.storage]
}

#--------------------------------------------------------------
# Role Assignment: Monitoring VM → Storage Accounts & Key Vault
# (Storage Module에서 처리하되, VM Identity는 여기서 전달)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_storage_reader" {
  count = var.enable_monitoring_vm ? 1 : 0

  provider = azurerm.hub

  scope                = module.hub_vnet.resource_group_id
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id

  depends_on = [module.monitoring_vm]
}

#--------------------------------------------------------------
# Spoke VNet Module
#--------------------------------------------------------------
module "spoke_vnet" {
  source = "./modules/dev/spoke/vnet"

  providers = {
    azurerm = azurerm.spoke
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group
  resource_group_name = local.spoke_resource_group_name

  # Virtual Network
  vnet_name          = local.spoke_vnet_name
  vnet_address_space = var.spoke_vnet_address_space
  subnets            = var.spoke_subnets

  # Hub VNet (for peering)
  hub_vnet_id             = module.hub_vnet.vnet_id
  hub_vnet_name           = module.hub_vnet.vnet_name
  hub_resource_group_name = module.hub_vnet.resource_group_name
  hub_monitoring_vm_subnet_id = module.hub_vnet.subnet_ids["Monitoring-VM-Subnet"]
  hub_key_vault_id       = module.storage.key_vault_id

  # Private DNS Zones (from Hub)
  private_dns_zone_ids = module.hub_vnet.private_dns_zone_ids

  # API Management
  apim_name            = local.spoke_apim_name
  apim_sku_name        = var.apim_sku_name
  apim_publisher_name  = var.apim_publisher_name
  apim_publisher_email = var.apim_publisher_email

  # Azure OpenAI
  openai_name        = local.spoke_openai_name
  openai_sku         = var.openai_sku
  openai_deployments = var.openai_deployments

  # AI Foundry
  ai_foundry_name = local.spoke_ai_foundry_name

  # Log Analytics (공통 모듈 출력)
  log_analytics_workspace_id = module.log_analytics_workspace.id

  # Hub Monitoring Storage (centralized logging)
  hub_monitoring_storage_ids = module.storage.monitoring_storage_account_ids

  depends_on = [module.hub_vnet, module.log_analytics_workspace, module.storage]
}

#--------------------------------------------------------------
# VNet Peering: Hub to Spoke (공통 모듈 vnet-peering)
#--------------------------------------------------------------
module "vnet_peering_hub_to_spoke" {
  source = "./terraform_modules/vnet-peering"

  providers = {
    azurerm = azurerm.hub
  }

  name                         = "${module.hub_vnet.vnet_name}-to-spoke"
  resource_group_name          = module.hub_vnet.resource_group_name
  virtual_network_name         = module.hub_vnet.vnet_name
  remote_virtual_network_id    = module.spoke_vnet.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false

  depends_on = [module.hub_vnet, module.spoke_vnet]
}

#--------------------------------------------------------------
# Role Assignments: Hub VM Managed Identity → Spoke Resources
# Allow monitoring VM to collect logs from Spoke resources via Private Endpoints
#--------------------------------------------------------------
# Spoke Key Vault: Key Vault Secrets User
resource "azurerm_role_assignment" "vm_spoke_key_vault_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.spoke_vnet.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# Spoke Storage Account: Storage Blob Data Contributor
resource "azurerm_role_assignment" "vm_spoke_storage_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.spoke_vnet.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# OpenAI: Cognitive Services User (for log collection - Data Plane)
resource "azurerm_role_assignment" "vm_openai_access" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.spoke_vnet.openai_id
  role_definition_name = "Cognitive Services User"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# OpenAI: Reader (for Management Plane API access - API key retrieval)
resource "azurerm_role_assignment" "vm_openai_reader" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.spoke_vnet.openai_id
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}

# Spoke Resource Group: Reader (for Management Plane API access)
resource "azurerm_role_assignment" "vm_spoke_reader" {
  provider = azurerm.spoke
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.spoke_vnet.resource_group_id
  role_definition_name = "Reader"
  principal_id         = module.monitoring_vm[0].identity_principal_id
}
