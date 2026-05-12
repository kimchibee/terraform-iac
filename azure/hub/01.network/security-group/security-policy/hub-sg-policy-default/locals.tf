locals {
  name_prefix = "${var.project_name}-x-x"
  hub_rg_name = data.terraform_remote_state.vnet_hub.outputs.hub_resource_group_name
}
