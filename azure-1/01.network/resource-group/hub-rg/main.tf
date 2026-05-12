module "resource_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-resources-resourcegroup?ref=main"

  name             = local.hub_resource_group_name
  location         = var.location
  tags             = var.tags
  enable_telemetry = false
}
