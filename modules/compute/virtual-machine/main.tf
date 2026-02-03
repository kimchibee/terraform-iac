#--------------------------------------------------------------
# VM Module - 공통 모듈
# Linux와 Windows VM 모두 지원
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Interface
#--------------------------------------------------------------
resource "azurerm_network_interface" "this" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

#--------------------------------------------------------------
# Linux Virtual Machine
#--------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "this" {
  count = var.os_type == "linux" ? 1 : 0

  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.size
  admin_username                  = var.admin_username
  disable_password_authentication = length(var.admin_ssh_keys) > 0
  admin_password                  = length(var.admin_ssh_keys) > 0 ? null : var.admin_password
  tags                            = var.tags

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  os_disk {
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = var.os_disk.disk_size_gb
  }

  source_image_reference {
    publisher = var.linux_image.publisher
    offer     = var.linux_image.offer
    sku       = var.linux_image.sku
    version   = var.linux_image.version
  }

  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_keys
    content {
      username   = admin_ssh_key.value.username
      public_key = admin_ssh_key.value.public_key
    }
  }

  identity {
    type = var.enable_identity ? "SystemAssigned" : "None"
  }

  boot_diagnostics {
    storage_account_uri = var.enable_boot_diagnostics ? var.boot_diagnostics_storage_account_uri : null
  }
}

#--------------------------------------------------------------
# Windows Virtual Machine
#--------------------------------------------------------------
resource "azurerm_windows_virtual_machine" "this" {
  count = var.os_type == "windows" ? 1 : 0

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  network_interface_ids = [
    azurerm_network_interface.this.id,
  ]

  os_disk {
    caching              = var.os_disk.caching
    storage_account_type = var.os_disk.storage_account_type
    disk_size_gb         = var.os_disk.disk_size_gb
  }

  source_image_reference {
    publisher = var.windows_image.publisher
    offer     = var.windows_image.offer
    sku       = var.windows_image.sku
    version   = var.windows_image.version
  }

  identity {
    type = var.enable_identity ? "SystemAssigned" : "None"
  }

  boot_diagnostics {
    storage_account_uri = var.enable_boot_diagnostics ? var.boot_diagnostics_storage_account_uri : null
  }
}

#--------------------------------------------------------------
# VM Extensions
#--------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "this" {
  for_each = {
    for ext in var.vm_extensions : ext.name => ext
  }

  name                       = each.value.name
  virtual_machine_id         = var.os_type == "linux" ? azurerm_linux_virtual_machine.this[0].id : azurerm_windows_virtual_machine.this[0].id
  publisher                  = each.value.publisher
  type                       = each.value.type
  type_handler_version       = each.value.type_handler_version
  auto_upgrade_minor_version = each.value.auto_upgrade_minor_version
  settings                   = jsonencode(each.value.settings)
  protected_settings         = jsonencode(each.value.protected_settings)
  tags                       = var.tags

  depends_on = [
    azurerm_linux_virtual_machine.this,
    azurerm_windows_virtual_machine.this
  ]
}
