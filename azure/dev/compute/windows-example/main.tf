#--------------------------------------------------------------
# Windows VM 모듈 (compute 루트에서 module로 호출)
# backend/remote_state 없음. resource_group_name, subnet_id 등은 루트에서 전달
#
# [신규 Windows VM 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) windows-example → windows-app-02
# 2. 이 폴더 내부 수정:
#    - 수정 불필요. (vm_name, admin_password 등은 루트에서 변수로 전달)
# 3. compute 루트에서 수정할 것:
#    - main.tf: module "windows_app_02" { source = "./windows-app-02"; ... } 블록 추가
#               vm_name = "${local.name_prefix}-${var.windows_app_02_vm_name}"
#               admin_password = var.windows_app_02_admin_password
#               application_security_group_ids = [for k in coalesce(var.windows_app_02_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
#    - variables.tf: windows_app_02_vm_name, windows_app_02_vm_size, windows_app_02_admin_username, windows_app_02_admin_password, windows_app_02_application_security_group_keys(default=null), windows_app_02_enable 등 추가
#    - terraform.tfvars: windows_app_02_vm_name = "win-app-02", windows_app_02_admin_password = "StrongP@ssw0rd!" 등 설정 (computer_name 15자 제한으로 VM 이름은 짧게)
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
