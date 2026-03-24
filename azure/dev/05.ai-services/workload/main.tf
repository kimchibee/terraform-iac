data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "azurerm_resource_group" "spoke" {
  name = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_name
}

locals {
  openai_deployments_map = {
    for d in var.openai_deployments : d.name => {
      name = d.name
      model = {
        format  = "OpenAI"
        name    = d.model_name
        version = d.version
      }
      scale = {
        type     = "Standard"
        capacity = d.capacity
      }
    }
  }
}

module "openai" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/cognitive-services-account?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  name                  = local.spoke_openai_name
  resource_group_id     = data.azurerm_resource_group.spoke.id
  location              = var.location
  kind                  = "OpenAI"
  sku_name              = var.openai_sku
  cognitive_deployments = local.openai_deployments_map
  tags                  = var.tags
}
