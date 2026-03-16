#--------------------------------------------------------------
# Compute Stack (루트)
# 하위 디렉터리(linux-monitoring-vm, windows-example 등)를 모듈로 호출.
# 루트는 컨텍스트(rg, subnet, location, tags, name_prefix, ASG)만 전달.
# 리소스 정보(사이즈, OS, 이름 접미사 등)는 각 하위 폴더의 variables.tf 기본값에서 관리.
# 신규 VM 추가: 폴더 복제 → 해당 폴더 variables.tf 기본값 수정 → 루트 main.tf에 module 블록만 추가 (Windows면 루트에 admin_password 변수 1개 추가)
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
  asg_id_by_key = {
    "keyvault_clients"   = try(data.terraform_remote_state.network.outputs.keyvault_clients_asg_id, null)
    "vm_allowed_clients" = try(data.terraform_remote_state.network.outputs.vm_allowed_clients_asg_id, null)
  }
  asg_ids = [for k in var.application_security_group_keys : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]
}

#--------------------------------------------------------------
# Linux Monitoring VM (rbac/storage 가 이 VM Identity 참조)
# 사이즈·이름 접미사·확장 등은 ./linux-monitoring-vm/variables.tf 기본값에서 관리
#--------------------------------------------------------------
module "linux_monitoring_vm" {
  source = "./linux-monitoring-vm"

  providers = {
    azurerm = azurerm.hub
  }

  name_prefix                   = local.name_prefix
  resource_group_name           = local.hub_rg
  subnet_id                     = local.hub_subnet
  location                      = var.location
  tags                          = var.tags
  application_security_group_ids = local.asg_ids
}

#--------------------------------------------------------------
# Windows VM 예시
# 사이즈·이름 접미사·확장 등은 ./windows-example/variables.tf 기본값에서 관리. 비밀번호만 루트에서 전달
#--------------------------------------------------------------
module "windows_example" {
  source = "./windows-example"

  providers = {
    azurerm = azurerm.hub
  }

  name_prefix                   = local.name_prefix
  resource_group_name           = local.hub_rg
  subnet_id                     = local.hub_subnet
  location                      = var.location
  tags                          = var.tags
  admin_password                = var.windows_example_admin_password
  application_security_group_ids = local.asg_ids
}
