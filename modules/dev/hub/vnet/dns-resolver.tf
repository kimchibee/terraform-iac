#--------------------------------------------------------------
# DNS Private Resolver
#--------------------------------------------------------------
resource "azurerm_private_dns_resolver" "hub" {
  name                = var.dns_resolver_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  virtual_network_id  = azurerm_virtual_network.hub.id
  tags                = var.tags
}

#--------------------------------------------------------------
# DNS Resolver Inbound Endpoint
#--------------------------------------------------------------
resource "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  name                    = "${var.dns_resolver_name}-inbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = azurerm_resource_group.hub.location
  tags                    = var.tags

  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = azurerm_subnet.subnets["DNSResolver-Inbound"].id
  }
}

#--------------------------------------------------------------
# DNS Resolver Outbound Endpoint
#--------------------------------------------------------------
resource "azurerm_private_dns_resolver_outbound_endpoint" "hub" {
  name                    = "${var.dns_resolver_name}-outbound"
  private_dns_resolver_id = azurerm_private_dns_resolver.hub.id
  location                = azurerm_resource_group.hub.location
  subnet_id               = azurerm_subnet.subnets["DNSResolver-Outbound"].id
  tags                    = var.tags
}

#--------------------------------------------------------------
# DNS Forwarding Ruleset
#--------------------------------------------------------------
resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub" {
  count = var.enable_dns_forwarding_ruleset ? 1 : 0

  name                                       = "${var.dns_resolver_name}-ruleset"
  resource_group_name                        = azurerm_resource_group.hub.name
  location                                   = azurerm_resource_group.hub.location
  private_dns_resolver_outbound_endpoint_ids = [azurerm_private_dns_resolver_outbound_endpoint.hub.id]
  tags                                       = var.tags
}

#--------------------------------------------------------------
# Link Ruleset to Hub VNet
#--------------------------------------------------------------
resource "azurerm_private_dns_resolver_virtual_network_link" "hub" {
  count = var.enable_dns_forwarding_ruleset ? 1 : 0

  name                      = "${var.dns_resolver_name}-vnet-link"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub[0].id
  virtual_network_id        = azurerm_virtual_network.hub.id
}
