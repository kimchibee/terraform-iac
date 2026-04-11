terraform {
  required_version = ">= 1.9.0, < 2.0"
}

# Legacy leaf kept only to preserve folder structure.
# Inbound endpoints are now managed in dns-private-resolver/hub leaf.
output "deprecated_leaf" {
  value = true
}
