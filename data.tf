#--------------------------------------------------------------
# Data Sources
# data "azurerm_..." 형태의 조회 전용 데이터 소스를 정의
# 기존 리소스 그룹, VNet, 서브넷, Key Vault, 현재 클라이언트 설정 등을 조회
#--------------------------------------------------------------

# 현재 Azure 클라이언트 설정 조회
data "azurerm_client_config" "current" {}

# 필요시 기존 리소스 조회 예시:
# data "azurerm_resource_group" "existing" {
#   name = "existing-resource-group"
# }
#
# data "azurerm_virtual_network" "existing" {
#   name                = "existing-vnet"
#   resource_group_name = data.azurerm_resource_group.existing.name
# }
#
# data "azurerm_key_vault" "existing" {
#   name                = "existing-keyvault"
#   resource_group_name = data.azurerm_resource_group.existing.name
# }
