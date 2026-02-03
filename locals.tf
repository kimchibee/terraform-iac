#--------------------------------------------------------------
# Local Values
# 공통 prefix, naming convention, 태그 등을 변수처럼 정의
# 복잡한 네이밍 규칙이나 반복되는 tag 세트를 DRY하게 유지
#--------------------------------------------------------------

locals {
  # 공통 네이밍 prefix
  name_prefix = "${var.project_name}-x-x"

  # Hub 리소스 이름
  hub_resource_group_name      = "${local.name_prefix}-rg"
  hub_vnet_name                = "${local.name_prefix}-vnet"
  hub_vpn_gateway_name         = "${local.name_prefix}-vpng"
  hub_dns_resolver_name        = "${local.name_prefix}-pdr"
  hub_vm_name                  = "${local.name_prefix}-vm"
  hub_key_vault_name           = "${var.project_name}-hub-kv"
  hub_log_analytics_name       = "${local.name_prefix}-law"

  # Spoke 리소스 이름
  spoke_resource_group_name = "${local.name_prefix}-spoke-rg"
  spoke_vnet_name           = "${local.name_prefix}-spoke-vnet"
  spoke_apim_name           = "${local.name_prefix}-apim"
  spoke_openai_name         = "${local.name_prefix}-aoai"
  spoke_ai_foundry_name     = "${local.name_prefix}-aifoundry"

  # 공통 태그 (variables.tf의 기본 태그와 병합)
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
