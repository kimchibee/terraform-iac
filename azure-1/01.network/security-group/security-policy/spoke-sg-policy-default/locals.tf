locals {
  name_prefix   = "${var.project_name}-x-x"
  spoke_rg_name = data.terraform_remote_state.vnet_spoke.outputs.spoke_resource_group_name
}
