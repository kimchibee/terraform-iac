terraform {
  required_version = ">= 1.9.0, < 2.0"
}

# Legacy leaf kept only to preserve folder structure.
# Subnet to NSG binding is now managed directly in subnet leaves:
# - subnet/hub-monitoring-vm-subnet
# - subnet/hub-pep-subnet
# - subnet/spoke-pep-subnet
output "deprecated_leaf" {
  value = true
}
