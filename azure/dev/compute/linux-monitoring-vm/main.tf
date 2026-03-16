#--------------------------------------------------------------
# Linux VM 모듈 (compute 루트에서 module로 호출)
# backend/remote_state 없음. resource_group_name, subnet_id 등은 루트에서 전달
#
# [신규 Linux VM 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) linux-monitoring-vm → linux-app-01
# 2. 이 폴더 내부 수정:
#    - 수정 불필요. (vm_name, vm_size, admin_username 등은 모두 루트에서 변수로 전달)
#    - SSH 키 파일명만 바꿀 경우: 루트 variables.tf의 해당 VM용 ssh_private_key_filename 변수로 지정
# 3. compute 루트에서 수정할 것:
#    - main.tf: module "linux_app_01" { source = "./linux-app-01"; ... } 블록 추가
#               vm_name = "${local.name_prefix}-${var.linux_app_01_vm_name}"
#               application_security_group_ids = [for k in coalesce(var.linux_app_01_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
#    - variables.tf: linux_app_01_vm_name, linux_app_01_vm_size, linux_app_01_ssh_key_filename, linux_app_01_application_security_group_keys(default=null), linux_app_01_enable, linux_app_01_extensions 등 추가
#    - terraform.tfvars: linux_app_01_vm_name = "app-01", linux_app_01_vm_size = "Standard_D2s_v3" 등 설정
#--------------------------------------------------------------

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
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_vm ? 1 : 0

  providers = {
    azurerm = azurerm
  }

  name                 = var.vm_name
  os_type              = "linux"
  size                 = var.vm_size
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.subnet_id
  admin_username       = var.admin_username
  admin_password       = ""
  admin_ssh_public_key = tls_private_key.vm_ssh[0].public_key_openssh
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
