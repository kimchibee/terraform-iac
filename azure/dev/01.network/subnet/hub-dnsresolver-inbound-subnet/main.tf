#--------------------------------------------------------------
# Hub ??DNSResolver-Inbound (`hub-dnsresolver-inbound-subnet`)
# ?�일 책임: DNS Resolver Inbound Subnet 1�??�성
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

locals {
  subnet_name = "DNSResolver-Inbound"
}

module "subnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/subnet?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.hub
  }

  name                 = local.subnet_name
  resource_group_name  = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
  virtual_network_name = data.terraform_remote_state.vnet_hub.outputs.hub_vnet_name
  address_prefixes     = ["10.0.0.64/28"]
  delegation = {
    name         = "Microsoft.Network.dnsResolvers"
    service_name = "Microsoft.Network/dnsResolvers"
    actions      = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
  }
}
