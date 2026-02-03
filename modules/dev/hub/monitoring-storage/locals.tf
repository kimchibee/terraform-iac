#--------------------------------------------------------------
# Local Values
# 공통 prefix, naming convention, 태그 등을 변수처럼 정의
# 복잡한 네이밍 규칙이나 반복되는 tag 세트를 DRY하게 유지
#--------------------------------------------------------------

locals {
  # Storage Account 목록 (terraform.tfvars에서 오버라이드 가능)
  # var.storage_accounts가 제공되면 사용, 아니면 기본값 사용
  storage_accounts = var.storage_accounts != null && length(var.storage_accounts) > 0 ? {
    for k, v in var.storage_accounts : k => try(v.name, "${var.project_name}${k}")
  } : {
    # Hub Resources
    "vpnglog"  = "${var.project_name}vpnglog"     # VPN Gateway logs
    "kvlog"    = "${var.project_name}kvlog"       # Hub Key Vault logs
    "nsglog"   = "${var.project_name}nsglog"      # NSG logs
    "vnetlog"  = "${var.project_name}vnetlog"     # VNet logs
    "vmlog"    = "${var.project_name}vmlog"       # VM logs
    "stgstlog" = "${var.project_name}stgstlog"    # Storage account logs (meta)
    # Spoke Resources (centralized in Hub)
    "aoailog"  = "${var.project_name}aoailog"     # Azure OpenAI logs
    "apimlog"  = "${var.project_name}apimlog"     # API Management logs
    "aiflog"   = "${var.project_name}aiflog"      # AI Foundry logs
    "acrlog"   = "${var.project_name}acrlog"      # Container Registry logs
    "spkvlog"  = "${var.project_name}spkvlog"     # Spoke Key Vault logs
  }

  # 공통 태그 (variables.tf의 기본 태그와 병합)
  common_tags = merge(
    var.tags,
    {
      Service     = "Storage"
      Purpose     = "Monitoring"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )

  # Key Vault 이름 (랜덤 suffix 포함)
  key_vault_name = var.enable_key_vault ? "${var.key_vault_name}${random_string.storage_suffix.result}" : null
}
