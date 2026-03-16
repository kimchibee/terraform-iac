#--------------------------------------------------------------
# Network Stack (루트)
# hub-vnet, spoke-vnet 은 하위 모듈로 호출. 신규 VNet 추가 시 디렉터리 복사 후 module 블록 + variables 추가
#--------------------------------------------------------------

locals {
  name_prefix              = "${var.project_name}-x-x"
  hub_resource_group_name  = "${local.name_prefix}-rg"
  hub_vnet_name            = "${local.name_prefix}-vnet"
  hub_vpn_gateway_name     = "${local.name_prefix}-vpng"
  hub_dns_resolver_name    = "${local.name_prefix}-pdr"
  hub_subnet_names         = toset(["GatewaySubnet", "DNSResolver-Inbound", "AzureFirewallSubnet", "AzureFirewallManagementSubnet", "AppGatewaySubnet", "Monitoring-VM-Subnet", "pep-snet"])
  hub_subnets              = { for k, v in var.hub_subnets : k => v if contains(local.hub_subnet_names, k) }
  # 시나리오 3: keyvault-sg — Hub NSG 키 → ID 매핑
  hub_nsg_id_by_key = {
    "monitoring_vm" = try(module.hub_vnet.nsg_monitoring_vm_id, null)
    "pep"           = try(module.hub_vnet.nsg_pep_id, null)
  }
  nsg_ids_add_keyvault_rule = [for k in var.hub_nsg_keys_add_keyvault_rule : local.hub_nsg_id_by_key[k] if try(local.hub_nsg_id_by_key[k], null) != null]
  subnet_ids_attach_keyvault_sg = [for n in var.hub_subnet_names_attach_keyvault_sg : module.hub_vnet.subnet_ids[n] if lookup(module.hub_vnet.subnet_ids, n, null) != null]
  # VM 타겟 단일 정책: 타겟 NSG ID 목록 (Hub 키 + 추가 ID)
  vm_access_target_nsg_ids = concat(
    [for k in var.vm_access_target_nsg_keys : local.hub_nsg_id_by_key[k] if try(local.hub_nsg_id_by_key[k], null) != null],
    coalesce(var.vm_access_target_nsg_ids_extra, [])
  )
  # Spoke-owned Private DNS Zones (image: zones in both Hub and Spoke for APIM, OpenAI, AI Foundry)
  spoke_private_dns_zones = coalesce(var.spoke_private_dns_zones, {
    "azure-api"         = "privatelink.azure-api.net"
    "openai"            = "privatelink.openai.azure.com"
    "cognitiveservices" = "privatelink.cognitiveservices.azure.com"
    "ml"                = "privatelink.api.azureml.ms"
    "notebooks"         = "privatelink.notebooks.azure.net"
  })
  # Static set of Hub Private DNS zone keys (so for_each in spoke module is known at plan time)
  hub_zone_keys_all = toset(["agentsvc", "azure-api", "blob", "cognitiveservices", "file", "ml", "monitor", "notebooks", "ods", "oms", "openai", "queue", "table", "vault"])
  hub_zone_keys_for_spoke = setsubtract(local.hub_zone_keys_all, keys(local.spoke_private_dns_zones))
  # Static map key => zone FQDN (for spoke link for_each; avoids "known only after apply")
  hub_zone_fqdn_by_key = {
    "agentsvc" = "privatelink.agentsvc.azure-automation.net"
    "azure-api" = "privatelink.azure-api.net"
    "blob" = "privatelink.blob.core.windows.net"
    "cognitiveservices" = "privatelink.cognitiveservices.azure.com"
    "file" = "privatelink.file.core.windows.net"
    "ml" = "privatelink.api.azureml.ms"
    "monitor" = "privatelink.monitor.azure.com"
    "notebooks" = "privatelink.notebooks.azure.net"
    "ods" = "privatelink.ods.opinsights.azure.com"
    "oms" = "privatelink.oms.opinsights.azure.com"
    "openai" = "privatelink.openai.azure.com"
    "queue" = "privatelink.queue.core.windows.net"
    "table" = "privatelink.table.core.windows.net"
    "vault" = "privatelink.vaultcore.azure.net"
  }
  hub_zone_names_for_spoke = { for k in local.hub_zone_keys_for_spoke : k => local.hub_zone_fqdn_by_key[k] }
  # Hub zone IDs for Spoke VNet link: exclude zones that exist in Spoke (one VNet cannot link to two zones with same namespace)
  hub_zone_ids_for_spoke_link = { for k, v in module.hub_vnet.private_dns_zone_ids : k => v if !contains(keys(local.spoke_private_dns_zones), k) }
}

module "hub_vnet" {
  source = "./hub-vnet"

  providers = {
    azurerm = azurerm.hub
  }

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags
  resource_group_name = local.hub_resource_group_name
  vnet_name          = local.hub_vnet_name
  vnet_address_space = var.hub_vnet_address_space
  subnets            = local.hub_subnets
  vpn_gateway_name   = local.hub_vpn_gateway_name
  vpn_gateway_sku    = var.vpn_gateway_sku
  vpn_gateway_type   = var.vpn_gateway_type
  local_gateway_configs = var.local_gateway_configs
  vpn_shared_key      = var.vpn_shared_key
  dns_resolver_name   = local.hub_dns_resolver_name
  enable_dns_forwarding_ruleset = var.enable_dns_forwarding_ruleset
}

module "spoke_vnet" {
  source = "./spoke-vnet"

  providers = {
    azurerm     = azurerm.spoke
    azurerm.hub = azurerm.hub
  }

  project_name             = var.project_name
  environment              = var.environment
  location                 = var.location
  tags                     = var.tags
  name_prefix              = local.name_prefix
  hub_vnet_id              = module.hub_vnet.vnet_id
  hub_resource_group_name  = module.hub_vnet.resource_group_name
  private_dns_zone_ids     = local.hub_zone_ids_for_spoke_link
  private_dns_zone_keys    = local.hub_zone_keys_for_spoke
  private_dns_zone_names   = local.hub_zone_names_for_spoke
  spoke_private_dns_zones  = local.spoke_private_dns_zones

  depends_on = [module.hub_vnet]
}

#--------------------------------------------------------------
# 시나리오 3: keyvault-sg — Key Vault 접근 허용 NSG 규칙
# - standalone NSG 생성 또는 기존 Hub NSG에 아웃바운드(Allow AzureKeyVault:443) 규칙 추가
#--------------------------------------------------------------
module "keyvault_sg" {
  count  = var.enable_keyvault_sg ? 1 : 0
  source = "./keyvault-sg"

  providers = {
    azurerm = azurerm.hub
  }

  resource_group_name           = local.hub_resource_group_name
  location                      = var.location
  tags                          = var.tags
  create_standalone_nsg          = true
  standalone_nsg_name            = "${local.name_prefix}-keyvault-sg"
  subnet_ids_attach_keyvault_sg  = local.subnet_ids_attach_keyvault_sg
  nsg_ids_add_keyvault_rule      = local.nsg_ids_add_keyvault_rule
  enable_pe_inbound_from_asg     = var.enable_pe_inbound_from_asg
  pe_nsg_id                      = var.enable_pe_inbound_from_asg ? module.hub_vnet.nsg_pep_id : null
  keyvault_clients_asg_name      = var.keyvault_clients_asg_name

  depends_on = [module.hub_vnet]
}

#--------------------------------------------------------------
# VM 타겟 단일 방화벽 정책 (ASG): 타겟 VM NSG 인바운드 = 소스 ASG, 포트 22/3389 등
# 클라이언트 VM NIC에 vm_allowed_clients_asg_id 붙이면 VNet 무관 한 정책으로 접속 허용
#--------------------------------------------------------------
module "vm_access_sg" {
  count  = var.enable_vm_access_sg ? 1 : 0
  source = "./vm-access-sg"

  providers = {
    azurerm = azurerm.hub
  }

  resource_group_name          = local.hub_resource_group_name
  location                     = var.location
  tags                         = var.tags
  enable_vm_access_sg          = var.enable_vm_access_sg
  vm_allowed_clients_asg_name  = var.vm_allowed_clients_asg_name
  target_nsg_ids               = local.vm_access_target_nsg_ids
  destination_ports            = var.vm_access_destination_ports

  depends_on = [module.hub_vnet]
}

# Spoke 구독 타겟 NSG에 VM 접근 허용 인바운드 규칙 추가 (동일 ASG 사용)
locals {
  vm_access_spoke_rules = var.enable_vm_access_sg && length(coalesce(var.vm_access_target_nsg_ids_spoke, [])) > 0 ? [
    for pair in setproduct(var.vm_access_target_nsg_ids_spoke, var.vm_access_destination_ports) : {
      key    = "${pair[0]}_${pair[1]}"
      nsg_id = pair[0]
      port   = pair[1]
    }
  ] : []
}
resource "azurerm_network_security_rule" "vm_access_sg_spoke" {
  for_each                               = { for r in local.vm_access_spoke_rules : r.key => r }
  provider                               = azurerm.spoke
  name                                   = "AllowVMClients-${each.value.port}"
  priority                               = 4090 + index(var.vm_access_destination_ports, each.value.port)
  direction                              = "Inbound"
  access                                 = "Allow"
  protocol                               = "Tcp"
  source_port_range                      = "*"
  destination_port_range                 = each.value.port
  source_application_security_group_ids = [module.vm_access_sg[0].vm_allowed_clients_asg_id]
  destination_address_prefix            = "*"
  resource_group_name                   = split("/", each.value.nsg_id)[4]
  network_security_group_name           = split("/", each.value.nsg_id)[8]
}
