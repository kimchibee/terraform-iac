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
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/application-security-group?ref=chore/avm-wave1-modules-prune-and-convert"

  enabled             = var.enabled
  name                = var.asg_name
  location            = data.terraform_remote_state.hub_rg.outputs.location
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  tags                = var.tags
}
