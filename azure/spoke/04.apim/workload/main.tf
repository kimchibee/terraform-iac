module "apim" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-apimanagement-service-main.git?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                = local.spoke_apim_name
  resource_group_name = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_name
  location            = var.location
  publisher_email     = var.apim_publisher_email
  publisher_name      = var.apim_publisher_name
  sku_name            = var.apim_sku_name
  tags                = var.tags
  enable_telemetry    = false
}
