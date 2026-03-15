module "shared_services" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/shared-services?ref=main"
  providers = { azurerm = azurerm }
  enable                      = var.enable
  resource_group_name         = var.resource_group_name
  log_analytics_workspace_id   = var.log_analytics_workspace_id
  log_analytics_workspace_name = var.log_analytics_workspace_name
  project_name                 = var.project_name
  location                     = var.location
  tags                         = var.tags
}
