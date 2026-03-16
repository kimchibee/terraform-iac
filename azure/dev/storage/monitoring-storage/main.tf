#--------------------------------------------------------------
# Monitoring Storage 모듈 (storage 루트에서 호출)
#
# [신규 Monitoring Storage 세트 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) monitoring-storage → monitoring-storage-02
# 2. 이 파일(main.tf)은 수정 불필요. (Git 모듈 그대로 사용)
# 3. storage 루트에서 수정할 것:
#    - main.tf: module "storage_02" { source = "./monitoring-storage-02"; ... } 블록 추가
#               (resource_group_name, key_vault_name, monitoring_vm_subnet_id, pep_subnet_id, private_dns_zone_ids 등은 remote_state.network / compute 동일 참조 또는 변수로 분리)
#    - variables.tf: storage_02용 변수 추가 (필요 시 key_vault_name 등)
#    - terraform.tfvars: 해당 변수 값 설정
#    - outputs.tf: 새 모듈 output 노출 (필요 시)
#--------------------------------------------------------------
module "storage" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/monitoring-storage?ref=main"

  providers = {
    azurerm = azurerm
  }

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags
  resource_group_name = var.resource_group_name
  key_vault_name      = var.key_vault_name
  monitoring_vm_subnet_id = var.monitoring_vm_subnet_id
  pep_subnet_id           = var.pep_subnet_id
  private_dns_zone_ids = var.private_dns_zone_ids
  enable_key_vault    = var.enable_key_vault
  monitoring_vm_identity_principal_id = var.monitoring_vm_identity_principal_id
  enable_monitoring_vm                 = var.enable_monitoring_vm
}
