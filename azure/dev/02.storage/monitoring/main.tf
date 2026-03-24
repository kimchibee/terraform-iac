locals {
  key_vault_name           = "${var.project_name}-${var.key_vault_suffix}"
  use_compute_remote_state = var.enable_monitoring_vm && var.monitoring_vm_identity_principal_id == ""
  monitoring_vm_principal_id = var.monitoring_vm_identity_principal_id != "" ? var.monitoring_vm_identity_principal_id : (
    local.use_compute_remote_state ? try(data.terraform_remote_state.compute[0].outputs.monitoring_vm_identity_principal_id, "") : ""
  )
  monitoring_storage_accounts = {
    aoailog      = "${var.project_name}${var.environment}aoai"
    apimlog      = "${var.project_name}${var.environment}apim"
    aifoundrylog = "${var.project_name}${var.environment}aifw"
    acrlog       = "${var.project_name}${var.environment}acr"
    spkvlog      = "${var.project_name}${var.environment}spkv"
  }
}

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/vnet/hub-vnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_monitoring_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_pep_subnet" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_blob_zone" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/private-dns-zone/hub-blob/terraform.tfstate"
  }
}

data "terraform_remote_state" "hub_vault_zone" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/private-dns-zone/hub-vault/terraform.tfstate"
  }
}

data "terraform_remote_state" "compute" {
  count   = local.use_compute_remote_state ? 1 : 0
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/06.compute/linux-monitoring-vm/terraform.tfstate"
  }
}

module "monitoring_storage" {
  for_each = local.monitoring_storage_accounts
  source   = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/storage-account?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = { azurerm = azurerm.hub }

  project_name                  = var.project_name
  environment                   = var.environment
  location                      = var.location
  resource_group_name           = data.terraform_remote_state.network.outputs.hub_resource_group_name
  storage_account_name          = substr(lower(replace(each.value, "-", "")), 0, 24)
  public_network_access_enabled = false
  tags                          = var.tags
}

module "monitoring_storage_blob_private_endpoint" {
  for_each = module.monitoring_storage
  source   = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-endpoint?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = { azurerm = azurerm.hub }

  project_name         = var.project_name
  environment          = var.environment
  name                 = "pe-${each.key}-blob"
  location             = var.location
  resource_group_name  = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_id            = data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id
  target_resource_id   = each.value.storage_account_id
  subresource_names    = ["blob"]
  private_dns_zone_ids = [data.terraform_remote_state.hub_blob_zone.outputs.private_dns_zone_id]
  tags                 = var.tags
}

module "key_vault" {
  count  = var.enable_key_vault ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/key-vault?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = { azurerm = azurerm.hub }

  project_name                  = var.project_name
  environment                   = var.environment
  name                          = local.key_vault_name
  location                      = var.location
  resource_group_name           = data.terraform_remote_state.network.outputs.hub_resource_group_name
  public_network_access_enabled = false
  network_acls = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id]
    ip_rules                   = []
  }
  tags = var.tags
}

module "key_vault_private_endpoint" {
  count  = var.enable_key_vault ? 1 : 0
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-endpoint?ref=chore/avm-wave1-modules-prune-and-convert"

  providers = { azurerm = azurerm.hub }

  project_name         = var.project_name
  environment          = var.environment
  name                 = "pe-hub-kv"
  location             = var.location
  resource_group_name  = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_id            = data.terraform_remote_state.hub_pep_subnet.outputs.hub_subnet_id
  target_resource_id   = module.key_vault[0].id
  subresource_names    = ["vault"]
  private_dns_zone_ids = [data.terraform_remote_state.hub_vault_zone.outputs.private_dns_zone_id]
  tags                 = var.tags
}

resource "azurerm_role_assignment" "monitoring_vm_key_vault_secrets_user" {
  count = var.enable_key_vault && var.enable_monitoring_vm && local.monitoring_vm_principal_id != "" ? 1 : 0

  scope                = module.key_vault[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.monitoring_vm_principal_id
}
