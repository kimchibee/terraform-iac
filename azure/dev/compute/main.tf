#--------------------------------------------------------------
# Compute Stack (루트)
# 하위 디렉터리(linux-monitoring-vm, windows-example 등)를 모듈로 호출.
# 신규 VM 추가: 디렉터리 복사 후 여기 module 블록 + variables 추가
#--------------------------------------------------------------

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project_name}-x-x"
  hub_rg      = data.terraform_remote_state.network.outputs.hub_resource_group_name
  hub_subnet  = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  # Network 스택 방화벽 정책(ASG): 변수명(키) → output ID 매핑. ID 직접 조회 없이 키만 지정
  asg_id_by_key = {
    "keyvault_clients"   = try(data.terraform_remote_state.network.outputs.keyvault_clients_asg_id, null)
    "vm_allowed_clients" = try(data.terraform_remote_state.network.outputs.vm_allowed_clients_asg_id, null)
  }
}

#--------------------------------------------------------------
# Linux Monitoring VM (rbac/storage 가 이 VM Identity 참조)
#--------------------------------------------------------------
module "linux_monitoring_vm" {
  source = "./linux-monitoring-vm"

  providers = {
    azurerm = azurerm.hub
  }

  resource_group_name     = local.hub_rg
  subnet_id               = local.hub_subnet
  location                = var.location
  vm_name                 = "${local.name_prefix}-${var.linux_monitoring_vm_name}"
  vm_size                 = var.linux_monitoring_vm_size
  admin_username          = var.linux_monitoring_vm_admin_username
  tags                    = var.tags
  vm_extensions           = var.linux_monitoring_vm_extensions
  ssh_private_key_filename = var.linux_monitoring_vm_ssh_key_filename
  enable_vm               = var.linux_monitoring_vm_enable
  application_security_group_ids = [for k in coalesce(var.linux_monitoring_vm_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
}

#--------------------------------------------------------------
# Windows VM 예시
#--------------------------------------------------------------
module "windows_example" {
  source = "./windows-example"

  providers = {
    azurerm = azurerm.hub
  }

  resource_group_name = local.hub_rg
  subnet_id           = local.hub_subnet
  location            = var.location
  vm_name             = "${local.name_prefix}-${var.windows_example_vm_name}"
  vm_size             = var.windows_example_vm_size
  admin_username      = var.windows_example_admin_username
  admin_password      = var.windows_example_admin_password
  tags                = var.tags
  vm_extensions       = var.windows_example_vm_extensions
  enable_vm           = var.windows_example_enable
  application_security_group_ids = [for k in coalesce(var.windows_example_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
}
