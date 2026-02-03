#--------------------------------------------------------------
# Data Sources
# 기존 리소스 조회를 위한 data 소스 정의
#--------------------------------------------------------------

# 현재 Azure 클라이언트 설정 조회
data "azurerm_client_config" "current" {}

# 기존 Storage Account 조회 (재사용 시)
data "azurerm_storage_account" "existing" {
  count               = var.existing_storage_account_name != null && var.existing_storage_account_name != "" ? 1 : 0
  name                = var.existing_storage_account_name
  resource_group_name = var.resource_group_name
}

# 기존 Key Vault 조회 (재사용 시)
data "azurerm_key_vault" "existing" {
  count               = var.existing_key_vault_name != null && var.existing_key_vault_name != "" ? 1 : 0
  name                = var.existing_key_vault_name
  resource_group_name = var.resource_group_name
}

# 기존 Subnet 조회 (Private Endpoint용)
data "azurerm_subnet" "pep" {
  count                = var.pep_subnet_id != null && var.pep_subnet_id != "" ? 1 : 0
  name                 = split("/", var.pep_subnet_id)[length(split("/", var.pep_subnet_id)) - 1]
  virtual_network_name = split("/", var.pep_subnet_id)[length(split("/", var.pep_subnet_id)) - 5]
  resource_group_name  = split("/", var.pep_subnet_id)[length(split("/", var.pep_subnet_id)) - 9]
}
