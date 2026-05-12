output "application_security_group_id" {
  value = try(module.application_security_group[0].resource_id, null)
}

output "application_security_group_name" {
  value = try(module.application_security_group[0].application_security_group.name, null)
}

output "vm_allowed_clients_asg_id" {
  value = try(module.application_security_group[0].resource_id, null)
}
