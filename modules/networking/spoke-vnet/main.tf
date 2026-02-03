#--------------------------------------------------------------
# Terraform Settings
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

#--------------------------------------------------------------
# Data Sources
#--------------------------------------------------------------
data "azurerm_client_config" "current" {}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------
resource "azurerm_resource_group" "spoke" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
resource "azurerm_virtual_network" "spoke" {
  name                = var.vnet_name
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

#--------------------------------------------------------------
# Subnets
#--------------------------------------------------------------
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                                          = each.key
  resource_group_name                           = azurerm_resource_group.spoke.name
  virtual_network_name                          = azurerm_virtual_network.spoke.name
  address_prefixes                              = each.value.address_prefixes
  service_endpoints                             = each.value.service_endpoints
  private_endpoint_network_policies_enabled     = each.value.private_endpoint_network_policies == "Enabled" ? true : false
  private_link_service_network_policies_enabled = each.value.private_link_service_network_policies == "Enabled" ? true : false

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }
}

#--------------------------------------------------------------
# Network Security Groups
#--------------------------------------------------------------
resource "azurerm_network_security_group" "apim" {
  name                = "${var.project_name}-apim-nsg"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowAPIMManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3443"
    source_address_prefix      = "ApiManagement"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6390"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.subnets["apim-snet"].id
  network_security_group_id = azurerm_network_security_group.apim.id
}

resource "azurerm_network_security_group" "pep" {
  name                = "${var.project_name}-spoke-pep-nsg"
  location            = azurerm_resource_group.spoke.location
  resource_group_name = azurerm_resource_group.spoke.name
  tags                = var.tags

  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "pep" {
  subnet_id                 = azurerm_subnet.subnets["pep-snet"].id
  network_security_group_id = azurerm_network_security_group.pep.id
}
