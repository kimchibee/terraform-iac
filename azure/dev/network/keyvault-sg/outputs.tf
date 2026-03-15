#--------------------------------------------------------------
# keyvault-sg 모듈 출력
#--------------------------------------------------------------

output "keyvault_sg_nsg_id" {
  description = "Standalone keyvault-sg NSG ID (null if create_standalone_nsg is false)"
  value       = var.create_standalone_nsg ? azurerm_network_security_group.keyvault_sg[0].id : null
}

output "keyvault_sg_nsg_name" {
  description = "Standalone keyvault-sg NSG name"
  value       = var.create_standalone_nsg ? azurerm_network_security_group.keyvault_sg[0].name : null
}

# PE 인바운드 1개 정책용 ASG — compute 스택에서 VM NIC에 연결 시 사용
output "keyvault_clients_asg_id" {
  description = "Key Vault 접근 허용 대상 ASG ID. Monitoring VM·Spoke Linux NIC의 application_security_group_ids에 넣으면 PE 쪽 인바운드 1개 정책으로 허용"
  value       = var.enable_pe_inbound_from_asg ? azurerm_application_security_group.keyvault_clients[0].id : null
}
