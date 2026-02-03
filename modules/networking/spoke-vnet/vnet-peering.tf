#--------------------------------------------------------------
# VNet Peering: Spoke to Hub
#--------------------------------------------------------------
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "${var.vnet_name}-to-hub"
  resource_group_name          = azurerm_resource_group.spoke.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = true

  depends_on = [
    azurerm_virtual_network.spoke
  ]
}

#--------------------------------------------------------------
# Link Private DNS Zones to Spoke VNet
#--------------------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = var.private_dns_zone_ids

  name                  = "${var.vnet_name}-link"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = split("/", each.value)[8]
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = var.tags
}
