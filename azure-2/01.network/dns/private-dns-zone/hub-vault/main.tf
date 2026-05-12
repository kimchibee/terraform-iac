module "zone" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privatednszone?ref=main"

  domain_name      = "privatelink.vaultcore.azure.net"
  parent_id        = data.azurerm_resource_group.parent.id
  tags             = var.tags
  enable_telemetry = false
}
