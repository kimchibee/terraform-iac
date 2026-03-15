output "resource_group_name" { value = module.spoke_vnet.resource_group_name }
output "resource_group_id" { value = module.spoke_vnet.resource_group_id }
output "vnet_id" { value = module.spoke_vnet.vnet_id }
output "vnet_name" { value = module.spoke_vnet.vnet_name }
output "vnet_address_space" { value = module.spoke_vnet.vnet_address_space }
output "subnet_ids" { value = module.spoke_vnet.subnet_ids }
output "spoke_private_dns_zone_ids" { value = module.spoke_vnet.spoke_private_dns_zone_ids }
output "spoke_private_dns_zone_names" { value = module.spoke_vnet.spoke_private_dns_zone_names }
