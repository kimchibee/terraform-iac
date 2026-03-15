#--------------------------------------------------------------
# Windows VM 모듈 (compute 루트에서 module로 호출)
# backend/remote_state 없음. resource_group_name, subnet_id 등은 루트에서 전달
#--------------------------------------------------------------

module "vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_vm ? 1 : 0

  providers = {
    azurerm = azurerm
  }

  name                 = var.vm_name
  os_type              = "windows"
  size                 = var.vm_size
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.subnet_id
  admin_username       = var.admin_username
  admin_password       = var.admin_password
  admin_ssh_public_key = ""
  tags                 = var.tags
  enable_identity      = true
  vm_extensions        = var.vm_extensions
}

# Network 스택 방화벽 정책(ASG) 반영: NIC에 ASG 연결
resource "azurerm_network_interface_application_security_group_association" "asg" {
  for_each                        = var.enable_vm && length(var.application_security_group_ids) > 0 ? toset(var.application_security_group_ids) : toset([])
  network_interface_id            = module.vm[0].network_interface_id
  application_security_group_id  = each.value
}
