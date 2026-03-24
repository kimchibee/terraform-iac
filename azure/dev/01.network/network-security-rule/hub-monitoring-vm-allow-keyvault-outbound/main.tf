terraform {
  required_version = ">= 1.9.0, < 2.0"
}

# Legacy leaf kept only to preserve folder structure.
# NSG rules are now managed in:
# - network-security-group/hub-monitoring-vm
# - network-security-group/hub-pep
output "deprecated_leaf" {
  value = true
}
