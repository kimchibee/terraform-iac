locals {
  gateway_subnet_id  = data.terraform_remote_state.gateway_subnet.outputs.hub_subnet_id
  virtual_network_id = regex("(?i)(.*/virtualNetworks/[^/]+)/subnets/[^/]+", local.gateway_subnet_id)[0]
}
