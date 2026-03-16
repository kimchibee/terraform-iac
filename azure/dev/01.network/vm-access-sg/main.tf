#--------------------------------------------------------------
# vm-access-sg: 일반 VM 타겟에 대한 단일 방화벽 정책 (ASG 기반)
# - 허용할 클라이언트용 ASG 1개 생성
# - 타겟 VM이 속한 서브넷(또는 VM)의 NSG에 인바운드 규칙: 소스=ASG, 포트(22/3389/443 등)
# - 클라이언트 VM NIC에 이 ASG를 붙이면 VNet 무관하게 한 정책으로 접속 허용
#--------------------------------------------------------------

resource "azurerm_application_security_group" "vm_allowed_clients" {
  count               = var.enable_vm_access_sg ? 1 : 0
  name                = var.vm_allowed_clients_asg_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# 타겟 NSG별·포트별 인바운드 규칙: 소스 = vm_allowed_clients ASG (Hub만; Spoke는 루트에서 처리)
locals {
  vm_access_rules = var.enable_vm_access_sg ? [
    for pair in setproduct(var.target_nsg_ids, var.destination_ports) : {
      key    = "${pair[0]}_${pair[1]}"
      nsg_id = pair[0]
      port   = pair[1]
    }
  ] : []
}

resource "azurerm_network_security_rule" "vm_inbound_from_clients" {
  for_each                               = { for r in local.vm_access_rules : r.key => r }
  name                                   = "AllowVMClients-${each.value.port}"
  priority                               = 4090 + index(var.destination_ports, each.value.port)
  direction                              = "Inbound"
  access                                 = "Allow"
  protocol                               = "Tcp"
  source_port_range                      = "*"
  destination_port_range                 = each.value.port
  source_application_security_group_ids = [azurerm_application_security_group.vm_allowed_clients[0].id]
  destination_address_prefix             = "*"
  resource_group_name                   = split("/", each.value.nsg_id)[4]
  network_security_group_name           = split("/", each.value.nsg_id)[8]
}
