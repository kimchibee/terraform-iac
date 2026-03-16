#--------------------------------------------------------------
# Windows VM 모듈 (compute 루트에서 module로 호출)
# 루트는 컨텍스트(name_prefix, rg, subnet, location, tags, ASG, admin_password)만 전달.
# 리소스 정보(사이즈, 이름 접미사, admin_username, vm_extensions)는 이 폴더 variables.tf 기본값으로 관리.
#
# [신규 Windows VM 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) windows-example → windows-app-02
# 2. 이 폴더에서만 수정: variables.tf 의 vm_name_suffix, vm_size, admin_username, vm_extensions 등 기본값
# 3. 루트 main.tf: module "windows_app_02" { source = "./windows-app-02"; ...; admin_password = var.windows_app_02_admin_password } 추가
#    루트 variables.tf / tfvars: 해당 Windows VM용 admin_password 만 추가 (보안상 루트에만 둠)
#--------------------------------------------------------------

locals {
  vm_name = "${var.name_prefix}-${var.vm_name_suffix}"
}

module "vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_vm ? 1 : 0

  providers = {
    azurerm = azurerm
  }

  name                 = local.vm_name
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
