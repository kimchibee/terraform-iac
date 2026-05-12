output "resource_group_name" {
  value = module.resource_group.name
}

output "resource_group_id" {
  value = module.resource_group.resource_id
}

output "location" {
  value = var.location
}
