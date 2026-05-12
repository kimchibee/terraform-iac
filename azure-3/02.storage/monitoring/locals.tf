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

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}
