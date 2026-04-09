output "application_security_group_id" {
  value = try(module.application_security_group[0].resource_id, null)
}

output "application_security_group_name" {
  value = try(module.application_security_group[0].application_security_group.name, null)
}

output "keyvault_clients_asg_id" {
  value = try(module.application_security_group[0].resource_id, null)
}
