#--------------------------------------------------------------
# Bastion Host
# Azure Bastion을 통한 안전한 VM 접근
#--------------------------------------------------------------
resource "azurerm_public_ip" "bastion" {
  name                = "${var.vnet_name}-bastion-pip"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "${var.vnet_name}-bastion"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnets["AzureBastionSubnet"].id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  depends_on = [azurerm_subnet.subnets]
}
