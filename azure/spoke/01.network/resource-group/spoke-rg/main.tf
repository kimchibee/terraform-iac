module "resource_group" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-resources-resourcegroup-main.git?ref=main"

  name             = local.spoke_resource_group_name
  location         = var.location
  tags             = var.tags
  enable_telemetry = false
}
