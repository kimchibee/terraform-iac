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


module "vm" {
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-compute-virtualmachine-main.git?ref=main"
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
