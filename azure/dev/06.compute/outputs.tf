#--------------------------------------------------------------
# Compute 루트 Outputs
# rbac/storage: monitoring_vm_identity_principal_id 로 이 state 참조
#--------------------------------------------------------------

output "linux_monitoring_vm_id" {
  value = module.linux_monitoring_vm.vm_id
}

output "linux_monitoring_vm_name" {
  value = module.linux_monitoring_vm.vm_name
}

output "linux_monitoring_vm_private_ip" {
  value = module.linux_monitoring_vm.vm_private_ip
}

output "linux_monitoring_vm_ssh_key_path" {
  value = module.linux_monitoring_vm.ssh_private_key_path
}

output "monitoring_vm_identity_principal_id" {
  description = "Linux Monitoring VM Identity (rbac/storage remote_state용)"
  value       = module.linux_monitoring_vm.identity_principal_id
}

output "windows_example_vm_id" {
  value = module.windows_example.vm_id
}

output "windows_example_vm_name" {
  value = module.windows_example.vm_name
}

output "windows_example_vm_private_ip" {
  value = module.windows_example.vm_private_ip
}
