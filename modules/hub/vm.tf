#--------------------------------------------------------------
# Network Interface for Monitoring VM
#--------------------------------------------------------------
resource "azurerm_network_interface" "monitoring_vm" {
  count = var.enable_monitoring_vm ? 1 : 0

  name                = "${var.vm_name}-nic"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnets["Monitoring-VM-Subnet"].id
    private_ip_address_allocation = "Dynamic"
  }
}

#--------------------------------------------------------------
# Monitoring Virtual Machine
#--------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "monitoring" {
  count = var.enable_monitoring_vm ? 1 : 0

  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.hub.name
  location                        = azurerm_resource_group.hub.location
  size                            = var.vm_size
  admin_username                  = var.vm_admin_username
  admin_password                  = var.vm_admin_password
  disable_password_authentication = false
  tags                            = var.tags

  lifecycle {
    ignore_changes = [size]
  }

  network_interface_ids = [
    azurerm_network_interface.monitoring_vm[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}

#--------------------------------------------------------------
# VM Extension - Azure Monitor Agent
#--------------------------------------------------------------
resource "azurerm_virtual_machine_extension" "ama" {
  count = var.enable_monitoring_vm ? 1 : 0

  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.monitoring[0].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}
