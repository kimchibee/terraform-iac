#--------------------------------------------------------------
# Linux VM 모듈 (compute 루트에서 module로 호출)
# 루트는 컨텍스트(name_prefix, rg, subnet, location, tags, ASG)만 전달.
# 리소스 정보(사이즈, OS, 이름 접미사 등)는 이 폴더 variables.tf 기본값으로 관리.
#
# [신규 Linux VM 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) linux-monitoring-vm → linux-app-01
# 2. 이 폴더에서만 수정: variables.tf 의 vm_name_suffix, vm_size, admin_username, vm_extensions 등 기본값
# 3. 루트 main.tf: module "linux_app_01" { source = "./linux-app-01"; name_prefix = local.name_prefix; resource_group_name = local.hub_rg; subnet_id = local.hub_subnet; location = var.location; tags = var.tags; application_security_group_ids = [...] } 만 추가 (VM별 변수 없음)
#--------------------------------------------------------------

locals {
  vm_name = "${var.name_prefix}-${var.vm_name_suffix}"
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

module "vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_vm ? 1 : 0

  providers = {
    azurerm = azurerm
  }

  name                 = local.vm_name
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
