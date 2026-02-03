#--------------------------------------------------------------
# Private DNS Zones
#--------------------------------------------------------------
locals {
  private_dns_zones = {
    # Storage
    "blob"  = "privatelink.blob.core.windows.net"
    "file"  = "privatelink.file.core.windows.net"
    "queue" = "privatelink.queue.core.windows.net"
    "table" = "privatelink.table.core.windows.net"

    # Key Vault
    "vault" = "privatelink.vaultcore.azure.net"

    # Azure OpenAI / Cognitive Services
    "openai"     = "privatelink.openai.azure.com"
    "cognitiveservices" = "privatelink.cognitiveservices.azure.com"

    # API Management
    "azure-api" = "privatelink.azure-api.net"

    # Azure Machine Learning / AI Foundry
    "ml"        = "privatelink.api.azureml.ms"
    "notebooks" = "privatelink.notebooks.azure.net"

    # Azure Monitor
    "monitor"         = "privatelink.monitor.azure.com"
    "oms"             = "privatelink.oms.opinsights.azure.com"
    "ods"             = "privatelink.ods.opinsights.azure.com"
    "agentsvc"        = "privatelink.agentsvc.azure-automation.net"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags
}

#--------------------------------------------------------------
# Link Private DNS Zones to Hub VNet
#--------------------------------------------------------------
resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = local.private_dns_zones

  name                  = "${var.vnet_name}-link"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
  tags                  = var.tags
}
