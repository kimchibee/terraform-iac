output "dns_private_resolver_id" {
  value = module.dns_private_resolver.resource_id
}

output "dns_private_resolver_inbound_endpoint_ids" {
  value = { for k, v in module.dns_private_resolver.inbound_endpoints : k => v.id }
}

output "dns_private_resolver_inbound_endpoint_ip_addresses" {
  value = module.dns_private_resolver.inbound_endpoint_ips
}
