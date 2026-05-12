module "monitoring_storage" {
  for_each = local.monitoring_storage_accounts
  source   = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-storage-storageaccount-main.git?ref=main"

  providers = { azurerm = azurerm.hub }

  name                          = substr(lower(replace(each.value, "-", "")), 0, 24)
  resource_group_name           = data.terraform_remote_state.network.outputs.hub_resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = local.common_tags
  enable_telemetry              = false
  shared_access_key_enabled     = true
}

module "monitoring_storage_blob_private_endpoint" {
  for_each = module.monitoring_storage
  source   = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-privateendpoint-main.git?ref=main"

  providers = { azurerm = azurerm.hub }

  name                            = "pe-${each.key}-blob"
  location                        = var.location
  resource_group_name             = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_resource_id              = data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id
  network_interface_name          = "nic-pe-${each.key}-blob"
  private_connection_resource_id  = each.value.resource_id
  subresource_names               = ["blob"]
  tags                            = local.common_tags
  enable_telemetry                = false
  private_service_connection_name = "psc-pe-${each.key}-blob"
  private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.hub_blob_zone.id]
  private_dns_zone_group_name     = "default"
}

module "key_vault" {
  count  = var.enable_key_vault ? 1 : 0
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-keyvault-vault-main.git?ref=main"

  providers = { azurerm = azurerm.hub }

  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = data.terraform_remote_state.network.outputs.hub_resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = false
  tags                          = local.common_tags
  enable_telemetry              = false
  network_acls = {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id]
    ip_rules                   = []
  }
}

module "key_vault_private_endpoint" {
  count  = var.enable_key_vault ? 1 : 0
  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-privateendpoint-main.git?ref=main"

  providers = { azurerm = azurerm.hub }

  name                            = "pe-hub-kv"
  location                        = var.location
  resource_group_name             = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_resource_id              = data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id
  network_interface_name          = "nic-pe-hub-kv"
  private_connection_resource_id  = module.key_vault[0].resource_id
  subresource_names               = ["vault"]
  tags                            = local.common_tags
  enable_telemetry                = false
  private_service_connection_name = "psc-pe-hub-kv"
  private_dns_zone_resource_ids   = [data.azurerm_private_dns_zone.hub_vault_zone.id]
  private_dns_zone_group_name     = "default"
}

resource "azurerm_role_assignment" "monitoring_vm_key_vault_secrets_user" {
  count = var.enable_key_vault && var.enable_monitoring_vm && local.monitoring_vm_principal_id != "" ? 1 : 0

  scope                = module.key_vault[0].resource_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.monitoring_vm_principal_id
}
