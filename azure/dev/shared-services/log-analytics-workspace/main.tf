module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=avm-1.0.0"
  providers = { azurerm = azurerm }
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}
