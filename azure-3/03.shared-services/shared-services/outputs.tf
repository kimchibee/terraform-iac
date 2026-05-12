output "action_group_id" { value = module.shared_services.action_group_id }
output "dashboard_id" { value = module.shared_services.dashboard_id }

# Legacy local shim retained for backward compatibility.
# shared-services composite module is removed in strict AVM mode.
output "deprecated_shim" {
  value = true
}
