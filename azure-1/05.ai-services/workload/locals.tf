#--------------------------------------------------------------
# AI Services Stack Local Values
#--------------------------------------------------------------

locals {
  name_prefix           = "${var.project_name}-x-x"
  spoke_openai_name     = "${local.name_prefix}-aoai"
  spoke_ai_foundry_name = "${local.name_prefix}-aifoundry"
}

locals {
  openai_deployments_map = {
    for d in var.openai_deployments : d.name => {
      name = d.name
      model = {
        format  = "OpenAI"
        name    = d.model_name
        version = d.version
      }
      scale = {
        type     = try(d.scale_type, "Standard")
        capacity = d.capacity
      }
    }
  }

  ai_foundry_storage_account_name = substr(
    replace(lower("${var.project_name}${var.environment}aif${random_string.ai_foundry_suffix.result}"), "-", ""),
    0,
    24
  )
  ai_foundry_workspace_name = "${local.spoke_ai_foundry_name}-${random_string.ai_foundry_suffix.result}"
}



locals {
  pep_common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}
