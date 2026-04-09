locals {
  name_prefix               = "${var.project_name}-x-x"
  spoke_resource_group_name = "${local.name_prefix}-spoke-rg"
}

module "resource_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-resources-resourcegroup?ref=main"

  name             = local.spoke_resource_group_name
  location         = var.location
  tags             = var.tags
  enable_telemetry = false
}
