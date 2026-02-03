#--------------------------------------------------------------
# VM Module Outputs
#--------------------------------------------------------------

output "vm_id" {
  description = "VM ID"
  value       = var.os_type == "linux" ? azurerm_linux_virtual_machine.this[0].id : azurerm_windows_virtual_machine.this[0].id
}

output "vm_name" {
  description = "VM 이름"
  value       = var.name
}

output "vm_private_ip" {
  description = "VM Private IP 주소"
  value       = azurerm_network_interface.this.private_ip_address
}

output "network_interface_id" {
  description = "Network Interface ID"
  value       = azurerm_network_interface.this.id
}

output "identity_principal_id" {
  description = "Managed Identity Principal ID"
  value = var.os_type == "linux" ? (
    var.enable_identity ? azurerm_linux_virtual_machine.this[0].identity[0].principal_id : null
  ) : (
    var.enable_identity ? azurerm_windows_virtual_machine.this[0].identity[0].principal_id : null
  )
}

output "identity_tenant_id" {
  description = "Managed Identity Tenant ID"
  value = var.os_type == "linux" ? (
    var.enable_identity ? azurerm_linux_virtual_machine.this[0].identity[0].tenant_id : null
  ) : (
    var.enable_identity ? azurerm_windows_virtual_machine.this[0].identity[0].tenant_id : null
  )
}
