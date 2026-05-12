locals {
  scope_refs = {
    "storage_key_vault_id"     = try(data.terraform_remote_state.storage.outputs.key_vault_id, "")
    "ai_services_openai_id"    = try(data.terraform_remote_state.ai_services.outputs.openai_id, "")
    "ai_services_key_vault_id" = try(data.terraform_remote_state.ai_services.outputs.key_vault_id, "")
    "ai_services_storage_id"   = try(data.terraform_remote_state.ai_services.outputs.storage_account_id, "")
    "network_hub_rg_id"        = try(data.terraform_remote_state.network_hub.outputs.hub_resource_group_id, "")
    "network_spoke_rg_id"      = try(data.terraform_remote_state.network_spoke.outputs.spoke_resource_group_id, "")
    "apim_id"                  = try(data.terraform_remote_state.apim.outputs.apim_id, "")
  }

  iam_role_assignments_resolved = [
    for r in var.iam_role_assignments : merge(r, {
      scope = (r.scope_ref != null && trimspace(r.scope_ref) != "") ? try(local.scope_refs[r.scope_ref], "") : (r.scope != null ? r.scope : "")
    })
  ]
  iam_role_assignments_valid = [for r in local.iam_role_assignments_resolved : r if r.scope != null && trimspace(r.scope) != ""]
  iam_for_hub = {
    for r in local.iam_role_assignments_valid :
    sha256("${r.principal_id}${r.scope}${r.role_definition_name}") => r if !r.use_spoke_provider
  }
}
