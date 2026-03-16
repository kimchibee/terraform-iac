#--------------------------------------------------------------
# vm-access-sg 모듈 출력
#--------------------------------------------------------------

output "vm_allowed_clients_asg_id" {
  description = "VM 접속 허용 클라이언트 ASG ID. 허용할 VM NIC의 application_security_group_ids에 넣으면 단일 정책으로 접속 허용"
  value       = var.enable_vm_access_sg ? azurerm_application_security_group.vm_allowed_clients[0].id : null
}
