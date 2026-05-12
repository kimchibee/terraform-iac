module "log_analytics_workspace" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-operationalinsights-workspace?ref=main"

  providers = { azurerm = azurerm.hub }

  name                                      = local.workspace_name
  location                                  = var.location
  resource_group_name                       = data.terraform_remote_state.network.outputs.hub_resource_group_name
  log_analytics_workspace_retention_in_days = var.retention_in_days
  tags                                      = var.tags
  enable_telemetry                          = false
}
