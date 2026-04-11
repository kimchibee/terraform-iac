locals {
  enabled   = var.ai_developer_group_object_id != null && trimspace(var.ai_developer_group_object_id) != ""
  openai_id = try(data.terraform_remote_state.ai_services.outputs.openai_id, null)
}
