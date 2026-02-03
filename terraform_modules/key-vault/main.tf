#-------------------------------------------------------------------------------
# Key Vault 모듈 - 메인 리소스
# 역할: Key Vault 1개 + 기본 설정. Private Endpoint는 private-endpoint 모듈로 별도 생성
#-------------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

resource "azurerm_key_vault" "main" {
  name                        = var.name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = var.sku_name
  soft_delete_retention_days   = var.soft_delete_retention_days
  purge_protection_enabled    = var.purge_protection_enabled
  public_network_access_enabled = var.public_network_access_enabled
  tags                        = local.common_tags

  dynamic "network_acls" {
    for_each = var.network_acls != null ? [var.network_acls] : []
    content {
      default_action             = network_acls.value.default_action
      bypass                     = join(",", network_acls.value.bypass)
      virtual_network_subnet_ids = network_acls.value.virtual_network_subnet_ids
      ip_rules                   = network_acls.value.ip_rules
    }
  }
}
