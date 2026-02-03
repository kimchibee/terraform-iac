#-------------------------------------------------------------------------------
# Private Endpoint 모듈 - 메인 리소스
# 역할: 대상 리소스 1개에 대한 PE 1개. DNS Zone 지정 시 자동으로 zone group 연결
#-------------------------------------------------------------------------------

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
  connection_name = coalesce(var.private_connection_name, "psc-${var.name}")
}

resource "azurerm_private_endpoint" "main" {
  name                = var.name
  location             = var.location
  resource_group_name  = var.resource_group_name
  subnet_id            = var.subnet_id
  tags                 = local.common_tags

  private_service_connection {
    name                           = local.connection_name
    private_connection_resource_id = var.target_resource_id
    subresource_names              = var.subresource_names
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = length(var.private_dns_zone_ids) > 0 ? [1] : []
    content {
      name                 = "default"
      private_dns_zone_ids  = var.private_dns_zone_ids
    }
  }
}
