#--------------------------------------------------------------
# API Management Stack Outputs
#--------------------------------------------------------------

output "apim_id" {
  description = "API Management ID"
  value       = module.apim.apim_id
}

output "apim_gateway_url" {
  description = "API Management gateway URL"
  value       = module.apim.apim_gateway_url
}

output "apim_private_ip_addresses" {
  description = "API Management private IP addresses"
  value       = module.apim.apim_private_ip_addresses
}
