#--------------------------------------------------------------
# Log Analytics Workspace — 리소스 정보(name_suffix, retention_in_days)는 이 폴더 variables.tf 기본값에서 관리.
# 루트는 name_prefix, location, resource_group_name, tags 만 전달.
# [신규 인스턴스 추가 시] 폴더 복사 후 variables.tf에서 name_suffix, retention_in_days 만 수정하고, 루트에 module 블록만 추가.
#--------------------------------------------------------------
locals {
  name = "${var.name_prefix}-${var.name_suffix}"
}

module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=avm-1.0.0"
  providers = { azurerm = azurerm }
  name                = local.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  retention_in_days    = var.retention_in_days
  tags                 = var.tags
}
