data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}

module "application_security_group" {
  count  = var.enabled ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-applicationsecuritygroup?ref=main"

  name                = var.asg_name
  location            = data.terraform_remote_state.hub_rg.outputs.location
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  tags                = var.tags
  enable_telemetry    = false
}
