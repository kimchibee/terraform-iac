locals {
  diag_storage_account_id = try(data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["acrlog"], null)
  hub_vpn_gateway_id      = try(data.terraform_remote_state.hub_vpn_gateway.outputs.virtual_network_gateway_id, null)
}
