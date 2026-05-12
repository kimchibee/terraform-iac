module "public_ip" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-publicipaddress-main.git?ref=main"

  name                = "${var.project_name}-x-x-vpng-pip"
  resource_group_name = data.terraform_remote_state.hub_rg.outputs.resource_group_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
  enable_telemetry    = false
}
