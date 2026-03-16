#--------------------------------------------------------------
# API Management Stack Local Values
#--------------------------------------------------------------

locals {
  name_prefix      = "${var.project_name}-x-x"
  spoke_apim_name  = "${local.name_prefix}-apim"
}
