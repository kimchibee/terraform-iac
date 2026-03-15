#--------------------------------------------------------------
# Monitoring Storage 모듈 (storage 루트에서 호출)
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
