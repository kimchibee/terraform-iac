data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

module "apim" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/api-management-service?ref=chore/avm-vendoring-and-id-injection"

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
}
