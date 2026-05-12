module "avm" {
  source  = "Azure/avm-res-cognitiveservices-account/azurerm"
  version = "0.11.0"

  name                          = var.name
  parent_id                     = var.resource_group_id
  location                      = var.location
  kind                          = var.kind
  sku_name                      = var.sku_name
  cognitive_deployments         = var.cognitive_deployments
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags
  enable_telemetry              = false
}
