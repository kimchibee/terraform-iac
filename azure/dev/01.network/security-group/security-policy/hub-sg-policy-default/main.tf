#--------------------------------------------------------------
# Hub Azure Firewall Policy (+ optional Azure Firewall)
# Prerequisite: `vnet/hub-vnet` (AzureFirewallSubnet in same Hub RG)
# Route leaves can reference `hub_firewall_private_ip` output as next hop
#--------------------------------------------------------------
data "terraform_remote_state" "vnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_firewall_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-azurefirewall-subnet/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-x-x"
  hub_rg_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}

data "azurerm_resource_group" "hub" {
  name = local.hub_rg_name
}

module "firewall_policy" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-firewallpolicy?ref=main"

  location            = data.azurerm_resource_group.hub.location
  name                = "${local.name_prefix}-fwpol"
  resource_group_name = data.azurerm_resource_group.hub.name
  tags                = var.tags

  firewall_policy_sku                      = var.firewall_sku_tier
  firewall_policy_threat_intelligence_mode = "Alert"

  enable_telemetry = false
}

resource "azurerm_public_ip" "firewall" {
  count = var.deploy_azure_firewall ? 1 : 0

  name                = "${local.name_prefix}-fw-pip"
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = data.azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.firewall_public_ip_zones
  tags                = var.tags
}

resource "azurerm_firewall" "hub" {
  count = var.deploy_azure_firewall ? 1 : 0

  name                = "${local.name_prefix}-fw"
  location            = data.azurerm_resource_group.hub.location
  resource_group_name = data.azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = module.firewall_policy.resource_id
  threat_intel_mode   = "Alert"
  zones               = var.firewall_zones
  tags                = var.tags

  ip_configuration {
    name                 = "primary"
    subnet_id            = data.terraform_remote_state.hub_firewall_subnet.outputs.hub_subnet_id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "openai_egress" {
  count = var.enable_openai_egress_rule ? 1 : 0

  name               = "openai-egress-rcg"
  firewall_policy_id = module.firewall_policy.resource_id
  priority           = 200

  application_rule_collection {
    name     = "allow-openai-https"
    priority = 210
    action   = "Allow"

    rule {
      name              = "monitoring-to-openai"
      source_addresses  = var.monitoring_subnet_cidrs
      destination_fqdns = var.openai_destination_fqdns

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}
