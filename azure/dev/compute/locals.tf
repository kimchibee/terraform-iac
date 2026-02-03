#--------------------------------------------------------------
# Compute Stack Local Values
#--------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-x-x"
  hub_vm_name = "${local.name_prefix}-vm"
}
