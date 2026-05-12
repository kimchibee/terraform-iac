output "public_ip_id" {
  value = module.public_ip.resource_id
}

output "public_ip_address" {
  value = module.public_ip.public_ip_address
}
