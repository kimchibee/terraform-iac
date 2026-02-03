#--------------------------------------------------------------
# AI Services Stack Local Values
#--------------------------------------------------------------

locals {
  name_prefix         = "${var.project_name}-x-x"
  spoke_openai_name   = "${local.name_prefix}-aoai"
  spoke_ai_foundry_name = "${local.name_prefix}-aifoundry"
}
