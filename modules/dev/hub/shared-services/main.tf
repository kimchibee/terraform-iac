#--------------------------------------------------------------
# Shared Services: Solutions / Action Group / Dashboard (IaC 전용)
# Log Analytics Workspace는 공통 모듈로 이미 생성됨. 여기선 그 위에 붙는 리소스만.
#--------------------------------------------------------------
resource "azurerm_log_analytics_solution" "container_insights" {
  count = var.enable ? 1 : 0

  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = var.log_analytics_workspace_id
  workspace_name        = var.log_analytics_workspace_name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_log_analytics_solution" "security_insights" {
  count = var.enable ? 1 : 0

  solution_name         = "SecurityInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = var.log_analytics_workspace_id
  workspace_name        = var.log_analytics_workspace_name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}

resource "azurerm_monitor_action_group" "main" {
  count = var.enable ? 1 : 0

  name                = "${var.project_name}-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "AlertGroup"
  tags                = var.tags

  email_receiver {
    name                    = "admin"
    email_address           = "admin@example.com"
    use_common_alert_schema = true
  }
}

resource "azurerm_portal_dashboard" "main" {
  count = var.enable ? 1 : 0

  name                = "${var.project_name}-dashboard"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          "0" = {
            position = { x = 0, y = 0, colSpan = 6, rowSpan = 4 }
            metadata = {
              type   = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = []
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = { relative = { duration = 24, timeUnit = 1 } }
          type  = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })
}
