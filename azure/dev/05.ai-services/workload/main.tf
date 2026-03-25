data "terraform_remote_state" "network_spoke" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "spoke_pep_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/spoke-pep-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "network_hub" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "azurerm_resource_group" "spoke" {
  name = data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_name
}

data "azurerm_private_dns_zone" "hub_openai" {
  provider            = azurerm.hub
  name                = "privatelink.openai.azure.com"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_azureml_api" {
  provider            = azurerm.hub
  name                = "privatelink.api.azureml.ms"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_notebooks" {
  provider            = azurerm.hub
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_client_config" "current" {}

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
  openai_endpoint_host      = trimsuffix(trimprefix(module.openai.endpoint, "https://"), "/")
  openai_private_dns_record = trimsuffix(local.openai_endpoint_host, ".openai.azure.com")
  openai_pe_private_ip      = try(data.azapi_resource.openai_pe[0].output.properties.customDnsConfigs[0].ipAddresses[0], null)
  ai_foundry_pe_custom_dns  = try(data.azapi_resource.ai_foundry_pe[0].output.properties.customDnsConfigs, [])

  # Map AI Foundry PE FQDNs to corresponding Hub private DNS zones.
  ai_foundry_dns_records = [
    for cfg in local.ai_foundry_pe_custom_dns : {
      fqdn = lower(try(cfg.fqdn, ""))
      ip   = try(cfg.ipAddresses[0], null)
      zone = endswith(lower(try(cfg.fqdn, "")), ".api.azureml.ms") ? data.azurerm_private_dns_zone.hub_azureml_api.name : (
        endswith(lower(try(cfg.fqdn, "")), ".notebooks.azure.net") ? data.azurerm_private_dns_zone.hub_notebooks.name : null
      )
      record_name = endswith(lower(try(cfg.fqdn, "")), ".api.azureml.ms") ? trimsuffix(lower(cfg.fqdn), ".api.azureml.ms") : (
        endswith(lower(try(cfg.fqdn, "")), ".notebooks.azure.net") ? trimsuffix(lower(cfg.fqdn), ".notebooks.azure.net") : null
      )
    } if try(cfg.fqdn, null) != null && try(cfg.ipAddresses[0], null) != null
  ]

  ai_foundry_dns_records_map = {
    for r in local.ai_foundry_dns_records : "${r.zone}::${r.record_name}" => r
    if r.zone != null && r.record_name != null
  }
}

module "openai" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/cognitive-services-account?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  name                  = local.spoke_openai_name
  resource_group_id     = data.azurerm_resource_group.spoke.id
  location              = var.location
  kind                  = "OpenAI"
  sku_name              = var.openai_sku
  cognitive_deployments = local.openai_deployments_map
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

module "openai_private_endpoint" {
  count  = var.enable_private_endpoints ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-endpoint?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  project_name         = var.project_name
  environment          = var.environment
  name                 = "${local.name_prefix}-aoai-pe"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.spoke.name
  subnet_id            = data.terraform_remote_state.spoke_pep_subnet.outputs.spoke_subnet_id
  target_resource_id   = module.openai.id
  subresource_names    = ["account"]
  private_dns_zone_ids = []
  tags                 = var.tags
}

data "azapi_resource" "openai_pe" {
  count = var.enable_private_endpoints ? 1 : 0

  type      = "Microsoft.Network/privateEndpoints@2024-07-01"
  parent_id = data.azurerm_resource_group.spoke.id
  name      = "${local.name_prefix}-aoai-pe"

  response_export_values = ["properties.customDnsConfigs"]
}

data "azapi_resource" "ai_foundry_pe" {
  count = var.enable_private_endpoints && var.enable_ai_foundry_workspace ? 1 : 0

  type      = "Microsoft.Network/privateEndpoints@2024-07-01"
  parent_id = data.azurerm_resource_group.spoke.id
  name      = "${local.name_prefix}-aif-pe"

  response_export_values = ["properties.customDnsConfigs"]
}

resource "azurerm_private_dns_a_record" "openai_in_hub_zone" {
  count = var.enable_private_endpoints && local.openai_pe_private_ip != null ? 1 : 0

  provider            = azurerm.hub
  name                = local.openai_private_dns_record
  zone_name           = data.azurerm_private_dns_zone.hub_openai.name
  resource_group_name = data.azurerm_private_dns_zone.hub_openai.resource_group_name
  ttl                 = 300
  records             = [local.openai_pe_private_ip]
}

resource "azurerm_private_dns_a_record" "ai_foundry_in_hub_zone" {
  for_each = local.ai_foundry_dns_records_map

  provider            = azurerm.hub
  name                = each.value.record_name
  zone_name           = each.value.zone
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
  ttl                 = 300
  records             = [each.value.ip]
}

module "ai_foundry_private_endpoint" {
  count  = var.enable_private_endpoints && var.enable_ai_foundry_workspace ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-endpoint?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = {
    azurerm = azurerm.spoke
  }

  project_name         = var.project_name
  environment          = var.environment
  name                 = "${local.name_prefix}-aif-pe"
  location             = var.location
  resource_group_name  = data.azurerm_resource_group.spoke.name
  subnet_id            = data.terraform_remote_state.spoke_pep_subnet.outputs.spoke_subnet_id
  target_resource_id   = azurerm_machine_learning_workspace.ai_foundry[0].id
  subresource_names    = ["amlworkspace"]
  private_dns_zone_ids = []
  tags                 = var.tags
}
