#--------------------------------------------------------------
# Data Sources
# data "azurerm_..." 형태의 조회 전용 데이터 소스를 정의
# 기존 VNet, 서브넷, Key Vault, 현재 클라이언트 설정 등을 조회
#--------------------------------------------------------------

# 현재 Azure 클라이언트 설정 조회
data "azurerm_client_config" "current" {}

# 기존 Virtual Network 조회
data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# 기존 Subnet 조회
data "azurerm_subnet" "apim" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# 기존 Key Vault 조회 (secrets용)
data "azurerm_key_vault" "apim_secrets" {
  count               = var.key_vault_name != null ? 1 : 0
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

# 기존 Log Analytics Workspace 조회
data "azurerm_log_analytics_workspace" "apim_logs" {
  count               = var.log_analytics_workspace_id != "" ? 1 : 0
  name                = split("/", var.log_analytics_workspace_id)[length(split("/", var.log_analytics_workspace_id)) - 1]
  resource_group_name = split("/", var.log_analytics_workspace_id)[length(split("/", var.log_analytics_workspace_id)) - 5]
}
