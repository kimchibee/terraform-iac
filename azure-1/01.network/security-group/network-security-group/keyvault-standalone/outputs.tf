output "network_security_group_id" {
  value = try(module.network_security_group[0].resource_id, null)
}

output "network_security_group_name" {
  value = try(module.network_security_group[0].name, null)
}

output "keyvault_standalone_nsg_id" {
  value = try(module.network_security_group[0].resource_id, null)
}
