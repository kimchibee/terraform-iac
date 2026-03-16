#--------------------------------------------------------------
# keyvault-sg (시나리오 3): Key Vault 접근 허용 NSG 규칙
# - standalone NSG 생성 + 아웃바운드 규칙(Allow AzureKeyVault:443)
# - 기존 NSG에 동일 규칙 추가 가능 (nsg_ids_add_keyvault_rule)
# - 서브넷에 standalone NSG 연결 가능 (subnet_ids_attach_keyvault_sg, NSG 없는 서브넷만)
# - [한 정책으로 Hub+Spoke] PE 쪽 인바운드 1개: 소스=ASG, 443 (enable_pe_inbound_from_asg)
#--------------------------------------------------------------

# Standalone keyvault-sg NSG (선택)
resource "azurerm_network_security_group" "keyvault_sg" {
  count               = var.create_standalone_nsg ? 1 : 0
  name                = var.standalone_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Standalone NSG 아웃바운드 규칙: Key Vault(443) 허용
resource "azurerm_network_security_rule" "keyvault_outbound_standalone" {
  count                        = var.create_standalone_nsg ? 1 : 0
  name                         = "AllowKeyVaultOutbound"
  priority                     = 4096
  direction                    = "Outbound"
  access                       = "Allow"
  protocol                     = "Tcp"
  source_port_range            = "*"
  destination_port_range       = "443"
  source_address_prefix        = "*"
  destination_address_prefix   = "AzureKeyVault"
  resource_group_name         = var.resource_group_name
  network_security_group_name  = azurerm_network_security_group.keyvault_sg[0].name
}

# Standalone NSG를 서브넷에 연결 (서브넷에 다른 NSG가 없을 때만 사용)
resource "azurerm_subnet_network_security_group_association" "keyvault_sg" {
  for_each                   = var.create_standalone_nsg ? toset(var.subnet_ids_attach_keyvault_sg) : toset([])
  subnet_id                  = each.value
  network_security_group_id  = var.create_standalone_nsg ? azurerm_network_security_group.keyvault_sg[0].id : null
}

# 기존 NSG에 Key Vault 아웃바운드 규칙 추가 (NSG ARM ID에서 resource_group_name / name 추출)
# ARM ID 형식: /subscriptions/.../resourceGroups/{rg}/.../networkSecurityGroups/{name}
resource "azurerm_network_security_rule" "keyvault_outbound_existing" {
  for_each                   = toset(var.nsg_ids_add_keyvault_rule)
  name                       = "AllowKeyVaultOutbound"
  priority                   = 4096
  direction                  = "Outbound"
  access                     = "Allow"
  protocol                   = "Tcp"
  source_port_range          = "*"
  destination_port_range     = "443"
  source_address_prefix      = "*"
  destination_address_prefix = "AzureKeyVault"
  resource_group_name        = split("/", each.value)[4]
  network_security_group_name = split("/", each.value)[8]
}

#--------------------------------------------------------------
# [한 정책으로 Hub+Spoke] Application Security Group + PE NSG 인바운드 1개
# - ASG를 Monitoring VM / Spoke Linux NIC에 붙이면, PE 쪽 인바운드 1개로 둘 다 허용
#--------------------------------------------------------------
resource "azurerm_application_security_group" "keyvault_clients" {
  count               = var.enable_pe_inbound_from_asg ? 1 : 0
  name                = var.keyvault_clients_asg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# PE 서브넷(pep-snet) NSG: 인바운드 — 소스 = keyvault-clients ASG, 포트 443
resource "azurerm_network_security_rule" "pe_inbound_from_keyvault_clients" {
  count                                      = var.enable_pe_inbound_from_asg && var.pe_nsg_id != null ? 1 : 0
  name                                       = "AllowKeyVaultClientsInbound443"
  priority                                   = 4095
  direction                                  = "Inbound"
  access                                     = "Allow"
  protocol                                   = "Tcp"
  source_port_range                          = "*"
  destination_port_range                     = "443"
  source_application_security_group_ids      = [azurerm_application_security_group.keyvault_clients[0].id]
  destination_address_prefix                 = "*"
  resource_group_name                        = split("/", var.pe_nsg_id)[4]
  network_security_group_name                = split("/", var.pe_nsg_id)[8]
}
