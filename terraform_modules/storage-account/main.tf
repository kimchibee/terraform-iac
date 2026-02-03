#-------------------------------------------------------------------------------
# Storage Account 모듈 - 메인 리소스
# 역할: Storage Account 1개 + 기본 설정. Private Endpoint/Blob 컨테이너는 별도 모듈 권장.
#-------------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  # 이름 미지정 시 prefix + 랜덤 4자 (Azure: 3~24자, 소문자+숫자만)
  name_prefix_used = substr(lower(replace(coalesce(var.name_prefix, "${var.project_name}${var.environment}"), "-", "")), 0, 20)
}

resource "random_string" "suffix" {
  count = var.storage_account_name == null ? 1 : 0

  length  = 4
  special = false
  upper   = false
  keepers = {
    project = var.project_name
    env     = var.environment
  }
}

locals {
  storage_account_name = var.storage_account_name != null ? var.storage_account_name : "${local.name_prefix_used}${random_string.suffix[0].result}"
}

resource "azurerm_storage_account" "main" {
  name                          = local.storage_account_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = var.account_tier
  account_replication_type      = var.account_replication_type
  min_tls_version               = var.min_tls_version
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = local.common_tags

  dynamic "network_rules" {
    for_each = var.network_rules != null ? [var.network_rules] : []
    content {
      default_action             = network_rules.value.default_action
      bypass                     = network_rules.value.bypass
      virtual_network_subnet_ids  = network_rules.value.virtual_network_subnet_ids
      ip_rules                   = network_rules.value.ip_rules
    }
  }
}
