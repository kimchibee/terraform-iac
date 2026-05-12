locals {
  name_prefix = "${var.project_name}-x-x"
  hub_rg      = data.terraform_remote_state.network.outputs.hub_resource_group_name
  hub_subnet  = data.terraform_remote_state.monitoring_subnet.outputs.hub_subnet_id
  asg_id_by_key = {
    "keyvault_clients"   = try(data.terraform_remote_state.network_subnet_hub.outputs.keyvault_clients_asg_id, null)
    "vm_allowed_clients" = try(data.terraform_remote_state.network_subnet_hub.outputs.vm_allowed_clients_asg_id, null)
  }
  asg_ids       = [for k in var.application_security_group_keys : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
  vm_name       = "${local.name_prefix}-${var.vm_name_suffix}"
  computer_name = "${local.name_prefix}-${var.vm_computer_name_suffix}"
}

locals {
  vm_source_image_reference = {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }
  vm_network_interfaces = {
    primary = {
      name = "${local.vm_name}-nic"
      ip_configurations = {
        primary = {
          name                          = "internal"
          private_ip_subnet_resource_id = local.hub_subnet
          private_ip_address_allocation = "Dynamic"
        }
      }
      is_primary = true
      tags       = var.tags
    }
  }
  vm_extensions_map = {
    for idx, ext in var.vm_extensions : tostring(idx) => {
      name                       = ext.name
      publisher                  = ext.publisher
      type                       = ext.type
      type_handler_version       = ext.type_handler_version
      auto_upgrade_minor_version = ext.auto_upgrade_minor_version
      settings                   = length(keys(ext.settings)) > 0 ? jsonencode(ext.settings) : null
      protected_settings         = length(keys(ext.protected_settings)) > 0 ? jsonencode(ext.protected_settings) : null
    }
  }
}
