locals {
  name_prefix = "${var.project_name}-x-x"
  nsg_name    = var.nsg_name != "" ? var.nsg_name : "${local.name_prefix}-keyvault-sg"
}

locals {
  nsg_security_rules = [
    {
      name                       = "AllowKeyVaultOutbound"
      priority                   = 4096
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "AzureKeyVault"
    }
  ]
}
