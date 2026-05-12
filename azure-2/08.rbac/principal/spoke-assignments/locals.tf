locals {
  vm_principal_id = try(data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id, null)
  enable_roles    = var.enable_monitoring_vm_roles && local.vm_principal_id != null
}
