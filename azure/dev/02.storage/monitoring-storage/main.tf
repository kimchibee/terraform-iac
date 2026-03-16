#--------------------------------------------------------------
# Monitoring Storage 모듈 (storage 루트에서 호출)
# 리소스 정보(Key Vault 이름 접미사, enable_key_vault, enable_monitoring_vm)는 이 폴더 variables.tf 기본값에서 관리.
# 루트는 remote_state로 얻은 resource_group_name, subnet_id, private_dns_zone_ids 등 컨텍스트만 전달.
#
# [신규 Monitoring Storage 세트 추가 시]
# 1. 이 폴더를 통째로 복사 후 폴더명 변경 (예: monitoring-storage-02)
# 2. 복사한 폴더의 variables.tf에서 key_vault_suffix, enable_key_vault, enable_monitoring_vm 등만 수정
# 3. 루트 main.tf에 module "storage_02" { source = "./monitoring-storage-02"; ... } 블록만 추가 (루트 variables/tfvars 추가 최소화)
#--------------------------------------------------------------
locals {
  key_vault_name = "${var.project_name}-${var.key_vault_suffix}"
}

module "storage" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/monitoring-storage?ref=main"

  providers = {
    azurerm = azurerm
  }

  project_name  = var.project_name
  environment   = var.environment
  location      = var.location
  tags          = var.tags
  resource_group_name = var.resource_group_name
  key_vault_name      = local.key_vault_name
  monitoring_vm_subnet_id = var.monitoring_vm_subnet_id
  pep_subnet_id           = var.pep_subnet_id
  private_dns_zone_ids = var.private_dns_zone_ids
  enable_key_vault    = var.enable_key_vault
  monitoring_vm_identity_principal_id = var.monitoring_vm_identity_principal_id
  enable_monitoring_vm                 = var.enable_monitoring_vm
}
