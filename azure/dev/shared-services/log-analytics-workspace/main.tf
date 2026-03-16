# [신규 Log Analytics Workspace 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) log-analytics-workspace → log-analytics-workspace-02
# 2. shared-services 루트에서 수정: main.tf에 module "log_analytics_workspace_02" { source = "./log-analytics-workspace-02"; name = local.hub_log_analytics_02_name; ... } 추가, locals에 name 추가, variables.tf·terraform.tfvars에 변수/값 추가
module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=avm-1.0.0"
  providers = { azurerm = azurerm }
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
