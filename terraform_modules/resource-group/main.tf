#-------------------------------------------------------------------------------
# Resource Group 모듈 - 메인 리소스
# 역할: Resource Group 1개만 생성
#-------------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = var.name
  location = var.location
  tags     = var.tags
}
