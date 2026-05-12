module "log_analytics_workspace" {
  source                                    = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-operationalinsights-workspace-main.git?ref=main"
  providers                                 = { azurerm = azurerm }
  name                                      = local.name
  location                                  = var.location
  resource_group_name                       = var.resource_group_name
  log_analytics_workspace_retention_in_days = var.retention_in_days
  tags                                      = var.tags
  enable_telemetry                          = false
}
