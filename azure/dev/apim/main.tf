#--------------------------------------------------------------
# API Management Stack
# API Management를 관리하는 스택
# AWS 방식: network 스택의 remote_state를 읽어서 의존성 해결
#--------------------------------------------------------------

#--------------------------------------------------------------
# Network Stack Remote State
#--------------------------------------------------------------
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Storage Stack Remote State (for Monitoring Storage)
#--------------------------------------------------------------
data "terraform_remote_state" "storage" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/storage/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# Shared Services Stack Remote State (for Log Analytics)
#--------------------------------------------------------------
data "terraform_remote_state" "shared_services" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/shared-services/terraform.tfstate"
  }
}

#--------------------------------------------------------------
# API Management Module
# 기존 spoke_vnet 모듈을 재사용하되, OpenAI와 AI Foundry는 제외
#--------------------------------------------------------------
module "apim" {
  source = "../../../modules/dev/spoke/vnet"

  providers = {
    azurerm = azurerm.spoke
  }

  # General
  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  # Resource Group (from network stack)
  resource_group_name = data.terraform_remote_state.network.outputs.spoke_resource_group_name

  # Virtual Network (from network stack - 재사용)
  vnet_name          = data.terraform_remote_state.network.outputs.spoke_vnet_name
  vnet_address_space = data.terraform_remote_state.network.outputs.spoke_vnet_address_space
  subnets            = {}  # Subnets는 network 스택에서 관리

  # Hub VNet (for peering)
  hub_vnet_id             = data.terraform_remote_state.network.outputs.hub_vnet_id
  hub_vnet_name           = data.terraform_remote_state.network.outputs.hub_vnet_name
  hub_resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  hub_monitoring_vm_subnet_id = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  hub_key_vault_id       = ""  # APIM은 Key Vault 불필요

  # Private DNS Zones (from network stack)
  private_dns_zone_ids = data.terraform_remote_state.network.outputs.hub_private_dns_zone_ids

  # API Management
  apim_name            = local.spoke_apim_name
  apim_sku_name        = var.apim_sku_name
  apim_publisher_name  = var.apim_publisher_name
  apim_publisher_email = var.apim_publisher_email

  # Azure OpenAI - 비활성화 (ai-services 스택에서 관리)
  openai_name        = ""
  openai_sku         = ""
  openai_deployments = []

  # AI Foundry - 비활성화 (ai-services 스택에서 관리)
  ai_foundry_name = ""

  # Log Analytics (from shared-services stack)
  log_analytics_workspace_id = data.terraform_remote_state.shared_services.outputs.log_analytics_workspace_id

  # Hub Monitoring Storage (from storage stack - APIM만 필요)
  hub_monitoring_storage_ids = {
    openai    = ""
    apim      = data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["apimlog"]
    aifoundry = ""
    acr       = ""
    spoke_kv  = ""
  }
}
