module "zone" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-privatednszone-main.git?ref=main"

  domain_name      = "privatelink.blob.core.windows.net"
  parent_id        = data.azurerm_resource_group.parent.id
  tags             = var.tags
  enable_telemetry = false
}
