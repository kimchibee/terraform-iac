#--------------------------------------------------------------
# Terraform Settings
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
    random = {
      source = "hashicorp/random"
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
resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
resource "azurerm_virtual_network" "hub" {
  name                = var.vnet_name
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

#--------------------------------------------------------------
# Subnets
#--------------------------------------------------------------
resource "azurerm_subnet" "subnets" {
  for_each = var.subnets

  name                                          = each.key
  resource_group_name                           = azurerm_resource_group.hub.name
  virtual_network_name                          = azurerm_virtual_network.hub.name
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
resource "azurerm_network_security_group" "monitoring_vm" {
  name                = "${var.project_name}-monitoring-vm-nsg"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  # Inbound Rules
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowRDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Outbound Rules - Allow access to Private Endpoints in pep-snet
  security_rule {
    name                       = "AllowOutboundToPrivateEndpoints"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow VM to access Private Endpoints in pep-snet subnet"
  }

  security_rule {
    name                       = "AllowOutboundHTTPS"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow HTTPS outbound for Azure services"
  }

  security_rule {
    name                       = "AllowOutboundHTTP"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "Allow HTTP outbound for Azure services"
  }
}

resource "azurerm_subnet_network_security_group_association" "monitoring_vm" {
  subnet_id                 = azurerm_subnet.subnets["Monitoring-VM-Subnet"].id
  network_security_group_id = azurerm_network_security_group.monitoring_vm.id
}

resource "azurerm_network_security_group" "pep" {
  name                = "${var.project_name}-pep-nsg"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
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
