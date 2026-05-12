output "spoke_route_table_id" {
  description = "Spoke Route Table ID"
  value       = module.route_table.resource_id
}

output "spoke_route_table_name" {
  value = module.route_table.name
}
