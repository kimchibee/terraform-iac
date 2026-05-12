locals {
  nsg_name = "${var.project_name}-x-x-monitoring-vm-nsg"
  nsg_security_rules = [
    {
      name                                  = "AllowVMClients-22"
      priority                              = 4090
      direction                             = "Inbound"
      access                                = "Allow"
      protocol                              = "Tcp"
      source_port_range                     = "*"
      destination_port_range                = "22"
      source_application_security_group_ids = [data.terraform_remote_state.vm_allowed_clients.outputs.vm_allowed_clients_asg_id]
      destination_address_prefix            = "*"
    },
    {
      name                                  = "AllowVMClients-3389"
      priority                              = 4091
      direction                             = "Inbound"
      access                                = "Allow"
      protocol                              = "Tcp"
      source_port_range                     = "*"
      destination_port_range                = "3389"
      source_application_security_group_ids = [data.terraform_remote_state.vm_allowed_clients.outputs.vm_allowed_clients_asg_id]
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
