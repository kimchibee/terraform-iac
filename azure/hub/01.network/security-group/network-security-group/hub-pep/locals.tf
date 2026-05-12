locals {
  nsg_name = "${var.project_name}-x-x-pep-nsg"
  nsg_security_rules = [
    {
      name                                  = "AllowKeyVaultClientsInbound443"
      priority                              = 4095
      direction                             = "Inbound"
      access                                = "Allow"
      protocol                              = "Tcp"
      source_port_range                     = "*"
      destination_port_range                = "443"
      source_application_security_group_ids = [data.terraform_remote_state.keyvault_clients.outputs.keyvault_clients_asg_id]
      destination_address_prefix            = "*"
    },
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
