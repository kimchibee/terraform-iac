#--------------------------------------------------------------
# VPN Gateway Public IP
#--------------------------------------------------------------
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "${var.vpn_gateway_name}-pip"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

#--------------------------------------------------------------
# VPN Gateway
#--------------------------------------------------------------
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = var.vpn_gateway_name
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  type                = var.vpn_gateway_type
  vpn_type            = "RouteBased"
  sku                 = var.vpn_gateway_sku
  active_active       = false
  enable_bgp          = false
  tags                = var.tags

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.subnets["GatewaySubnet"].id
  }
}

#--------------------------------------------------------------
# Local Network Gateways
#--------------------------------------------------------------
resource "azurerm_local_network_gateway" "onprem" {
  for_each = { for lgw in var.local_gateway_configs : lgw.name => lgw }

  name                = "${var.project_name}-x-x-${each.value.name}"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  gateway_address     = each.value.gateway_address
  address_space       = each.value.address_space
  tags                = var.tags

  dynamic "bgp_settings" {
    for_each = each.value.bgp_settings != null ? [each.value.bgp_settings] : []
    content {
      asn                 = bgp_settings.value.asn
      bgp_peering_address = bgp_settings.value.bgp_peering_address
    }
  }
}

#--------------------------------------------------------------
# VPN Connections
#--------------------------------------------------------------
resource "azurerm_virtual_network_gateway_connection" "onprem" {
  for_each = { for lgw in var.local_gateway_configs : lgw.name => lgw }

  name                       = "${var.project_name}-x-x-vcn-${index(var.local_gateway_configs, each.value) + 1}"
  location                   = azurerm_resource_group.hub.location
  resource_group_name        = azurerm_resource_group.hub.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.onprem[each.key].id
  shared_key                 = var.vpn_shared_key
  tags                       = var.tags

  ipsec_policy {
    dh_group         = "DHGroup14"
    ike_encryption   = "AES256"
    ike_integrity    = "SHA256"
    ipsec_encryption = "AES256"
    ipsec_integrity  = "SHA256"
    pfs_group        = "PFS14"
    sa_datasize      = 102400000
    sa_lifetime      = 28800
  }
}
