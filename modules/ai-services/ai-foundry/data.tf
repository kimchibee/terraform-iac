#--------------------------------------------------------------
# Data Sources
# data "azurerm_..." 형태의 조회 전용 데이터 소스를 정의
# 기존 VNet, 서브넷, Storage Account, Key Vault, Container Registry 등을 조회
#--------------------------------------------------------------

# 기존 Virtual Network 조회
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# 기존 Private Endpoint Subnet 조회
data "azurerm_subnet" "pep" {
  name                 = var.pep_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# 기존 Storage Account 조회 (재사용 시)
data "azurerm_storage_account" "workspace_storage" {
  count               = var.existing_storage_account_name != null && var.existing_storage_account_name != "" ? 1 : 0
  name                = var.existing_storage_account_name
  resource_group_name = var.resource_group_name
}

# 기존 Container Registry 조회 (재사용 시)
data "azurerm_container_registry" "workspace_acr" {
  count               = var.existing_acr_name != null && var.existing_acr_name != "" ? 1 : 0
  name                = var.existing_acr_name
  resource_group_name = var.resource_group_name
}

# 기존 Key Vault 조회
data "azurerm_key_vault" "workspace_kv" {
  name                = split("/", var.hub_key_vault_id)[length(split("/", var.hub_key_vault_id)) - 1]
  resource_group_name = split("/", var.hub_key_vault_id)[length(split("/", var.hub_key_vault_id)) - 5]
}

# 기존 Log Analytics Workspace 조회
data "azurerm_log_analytics_workspace" "workspace" {
  count               = var.log_analytics_workspace_id != "" ? 1 : 0
  name                = split("/", var.log_analytics_workspace_id)[length(split("/", var.log_analytics_workspace_id)) - 1]
  resource_group_name = split("/", var.log_analytics_workspace_id)[length(split("/", var.log_analytics_workspace_id)) - 5]
}
