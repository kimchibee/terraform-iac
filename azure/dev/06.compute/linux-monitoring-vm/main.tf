# Linux Monitoring VM leaf (applies using network remote state references)
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_subnet_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-x-x"
  hub_rg      = data.terraform_remote_state.network.outputs.hub_resource_group_name
  hub_subnet  = data.terraform_remote_state.monitoring_subnet.outputs.hub_subnet_id
  asg_id_by_key = {
    "keyvault_clients"   = try(data.terraform_remote_state.network_subnet_hub.outputs.keyvault_clients_asg_id, null)
    "vm_allowed_clients" = try(data.terraform_remote_state.network_subnet_hub.outputs.vm_allowed_clients_asg_id, null)
  }
  asg_ids = [for k in var.application_security_group_keys : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
  vm_name = "${local.name_prefix}-${var.vm_name_suffix}"
}

resource "tls_private_key" "vm_ssh" {
  count     = var.enable_vm ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "vm_private_key_pem" {
  count           = var.enable_vm ? 1 : 0
  content         = tls_private_key.vm_ssh[0].private_key_pem
  filename        = "${path.root}/${var.ssh_private_key_filename}"
  file_permission = "0600"
}

locals {
  vm_source_image_reference = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
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

module "vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-compute-virtualmachine?ref=main"
  count  = var.enable_vm ? 1 : 0

  providers = {
    azurerm = azurerm
  }

  name                = local.vm_name
  resource_group_name = local.hub_rg
  location            = var.location
  zone                = "1"

  os_type                = "Linux"
  sku_size               = var.vm_size
  source_image_reference = local.vm_source_image_reference
  network_interfaces     = local.vm_network_interfaces
  extensions             = local.vm_extensions_map

  admin_username = var.admin_username
  admin_password = null
  admin_ssh_keys = [
    {
      username   = var.admin_username
      public_key = tls_private_key.vm_ssh[0].public_key_openssh
    }
  ]

  managed_identities = {
    system_assigned            = true
    user_assigned_resource_ids = []
  }

  tags             = var.tags
  enable_telemetry = false
}

resource "azurerm_network_interface_application_security_group_association" "asg" {
  for_each                      = var.enable_vm && length(local.asg_ids) > 0 ? toset(local.asg_ids) : toset([])
  network_interface_id          = try(values(module.vm[0].network_interfaces)[0].id, null)
  application_security_group_id = each.value
}
