locals {
  openai_deployments_map = {
    for d in var.openai_deployments : d.name => {
      name = d.name
      model = {
        format  = "OpenAI"
        name    = d.model_name
        version = d.version
      }
      scale = {
        type     = try(d.scale_type, "Standard")
        capacity = d.capacity
      }
    }
  }

  ai_foundry_storage_account_name = substr(
    replace(lower("${var.project_name}${var.environment}aif${random_string.ai_foundry_suffix.result}"), "-", ""),
    0,
    24
  )
  ai_foundry_workspace_name = "${local.spoke_ai_foundry_name}-${random_string.ai_foundry_suffix.result}"
}

module "openai" {
  source = "./modules/cognitive-services-account"

  providers = {
    azurerm = azurerm.spoke
  }

  name                  = local.spoke_openai_name
  resource_group_id     = data.azurerm_resource_group.spoke.id
  location              = var.location
  kind                  = "OpenAI"
  sku_name              = var.openai_sku
  cognitive_deployments = local.openai_deployments_map
  public_network_access_enabled = false
  tags                  = var.tags
}

resource "random_string" "ai_foundry_suffix" {
  length  = 4
  upper   = false
  special = false
}

resource "azurerm_log_analytics_workspace" "ai_foundry" {
  name                = "${local.name_prefix}-aif-law"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.spoke.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "ai_foundry" {
  name                = "${local.name_prefix}-aif-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.spoke.name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.ai_foundry.id
  tags                = var.tags
}

resource "azurerm_storage_account" "ai_foundry" {
  name                     = local.ai_foundry_storage_account_name
  resource_group_name      = data.azurerm_resource_group.spoke.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_key_vault" "ai_foundry" {
  name                          = "${local.name_prefix}-aif-kv-${random_string.ai_foundry_suffix.result}"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.spoke.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  soft_delete_retention_days    = 7
  purge_protection_enabled      = false
  public_network_access_enabled = false
  tags                          = var.tags
}

resource "azurerm_machine_learning_workspace" "ai_foundry" {
  count = var.enable_ai_foundry_workspace ? 1 : 0

  name                          = local.ai_foundry_workspace_name
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.spoke.name
  application_insights_id       = azurerm_application_insights.ai_foundry.id
  key_vault_id                  = azurerm_key_vault.ai_foundry.id
  storage_account_id            = azurerm_storage_account.ai_foundry.id
  public_network_access_enabled = false
  identity {
    type = "SystemAssigned"
  }
  tags = var.tags
}


locals {
  pep_common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

module "openai_private_endpoint" {
  count  = var.enable_private_endpoints ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privateendpoint?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                            = "${local.name_prefix}-aoai-pe"
  location                        = var.location
  resource_group_name             = data.azurerm_resource_group.spoke.name
  subnet_resource_id              = data.terraform_remote_state.spoke_pep_subnet.outputs.spoke_subnet_id
  network_interface_name          = "nic-${local.name_prefix}-aoai-pe"
  private_connection_resource_id  = module.openai.id
  subresource_names               = ["account"]
  tags                            = local.pep_common_tags
  enable_telemetry                = false
  private_service_connection_name = "psc-${local.name_prefix}-aoai-pe"
  private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.hub_openai.id]
  private_dns_zone_group_name     = "default"
}

module "ai_foundry_private_endpoint" {
  count  = var.enable_private_endpoints && var.enable_ai_foundry_workspace ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-privateendpoint?ref=main"

  providers = {
    azurerm = azurerm.spoke
  }

  name                            = "${local.name_prefix}-aif-pe"
  location                        = var.location
  resource_group_name             = data.azurerm_resource_group.spoke.name
  subnet_resource_id              = data.terraform_remote_state.spoke_pep_subnet.outputs.spoke_subnet_id
  network_interface_name          = "nic-${local.name_prefix}-aif-pe"
  private_connection_resource_id  = azurerm_machine_learning_workspace.ai_foundry[0].id
  subresource_names               = ["amlworkspace"]
  tags                            = local.pep_common_tags
  enable_telemetry                = false
  private_service_connection_name = "psc-${local.name_prefix}-aif-pe"
  private_dns_zone_resource_ids = [
    data.azurerm_private_dns_zone.hub_azureml_api.id,
    data.azurerm_private_dns_zone.hub_notebooks.id
  ]
  private_dns_zone_group_name = "default"
}
