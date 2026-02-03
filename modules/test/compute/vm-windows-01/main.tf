#--------------------------------------------------------------
# Windows VM Instance - vm-windows-01
# 공통 _vm-module을 호출하여 Windows VM 생성
#--------------------------------------------------------------

#--------------------------------------------------------------
# VNet에서 서브넷 조회
#--------------------------------------------------------------
data "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

#--------------------------------------------------------------
# 서브넷 조회 (subnet_name으로 필터링)
#--------------------------------------------------------------
data "azurerm_subnet" "selected" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}

#--------------------------------------------------------------
# VM Module 호출
#--------------------------------------------------------------
module "vm" {
  source = "../_vm-module"

  name                = var.vm_name
  os_type             = "windows"
  size                = var.vm_size
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.selected.id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  # Windows 이미지 설정
  windows_image = var.windows_image

  # OS 디스크 설정
  os_disk = var.os_disk

  # Identity 설정
  enable_identity = var.enable_identity

  # Boot Diagnostics 설정
  enable_boot_diagnostics            = var.enable_boot_diagnostics
  boot_diagnostics_storage_account_uri = var.boot_diagnostics_storage_account_uri

  # VM Extensions
  vm_extensions = var.vm_extensions
}
