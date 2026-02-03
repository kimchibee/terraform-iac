#--------------------------------------------------------------
# Terraform Settings
#--------------------------------------------------------------
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

#--------------------------------------------------------------
# Log Analytics Workspace
#--------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

#--------------------------------------------------------------
# Log Analytics Solutions
#--------------------------------------------------------------
resource "azurerm_log_analytics_solution" "container_insights" {
  count = var.enable_shared_services ? 1 : 0

  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_log_analytics_solution" "security_insights" {
  count = var.enable_shared_services ? 1 : 0

  solution_name         = "SecurityInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name
  tags                  = var.tags

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SecurityInsights"
  }
}

#--------------------------------------------------------------
# Azure Monitor Action Group
#--------------------------------------------------------------
resource "azurerm_monitor_action_group" "main" {
  count = var.enable_shared_services ? 1 : 0

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

#--------------------------------------------------------------
# Dashboard
#--------------------------------------------------------------
resource "azurerm_portal_dashboard" "main" {
  count = var.enable_shared_services ? 1 : 0

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
            position = {
              x          = 0
              y          = 0
              colSpan    = 6
              rowSpan    = 4
            }
            metadata = {
              type = "Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"
              inputs = []
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })
}
