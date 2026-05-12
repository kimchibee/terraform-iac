module "firewall_policy" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-firewallpolicy-main.git?ref=main"

  location            = data.azurerm_resource_group.spoke.location
  name                = "${local.name_prefix}-spoke-fwpol"
  resource_group_name = data.azurerm_resource_group.spoke.name
  tags                = var.tags

  firewall_policy_sku                      = var.firewall_sku_tier
  firewall_policy_threat_intelligence_mode = "Alert"

  enable_telemetry = false
}

resource "azurerm_public_ip" "firewall" {
  count = var.deploy_azure_firewall ? 1 : 0

  name                = "${local.name_prefix}-spoke-fw-pip"
  location            = data.azurerm_resource_group.spoke.location
  resource_group_name = data.azurerm_resource_group.spoke.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall_public_ip_zones
  tags                = var.tags
}

resource "azurerm_firewall" "spoke" {
  count = var.deploy_azure_firewall ? 1 : 0

  name                = "${local.name_prefix}-spoke-fw"
  location            = data.azurerm_resource_group.spoke.location
  resource_group_name = data.azurerm_resource_group.spoke.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = module.firewall_policy.resource_id
  threat_intel_mode   = "Alert"
  zones               = var.firewall_zones
  tags                = var.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = var.firewall_subnet_id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}
