# Strict AVM Foundation Migration Guide

This guide documents the strict AVM-only foundation migration path.

## Policy

- Shared modules allowed in foundation must be AVM-only.
- Non-AVM shared modules are deferred.
- Deprecated composite modules are not allowed for new leaves.
- IaC leaves must consume shared modules through Git `source`.

## Foundation in-scope shared modules

- `resource-group`
- `vnet`
- `storage-account`
- `key-vault`
- `log-analytics-workspace`
- `private-endpoint`
- `firewall-policy`
- `route-table`
- `application-security-group`
- `network-security-group`

## Deferred shared modules (non-AVM)

- `subnet`
- `private-dns-zone`
- `private-dns-zone-vnet-link`
- `dns-private-resolver`
- `dns-private-resolver-inbound-endpoint`
- `public-ip`
- `virtual-network-gateway`
- `local-network-gateway`
- `virtual-network-gateway-connection`
- `network-security-rule`
- `subnet-network-security-group-association`
- `vnet-peering`
- `virtual-machine`

## Deprecated composite modules

- `hub-vnet`
- `spoke-vnet`
- `spoke-workloads`
- `shared-services`
- `monitoring-storage`
- `subnet-keyvault-sg`
- `subnet-vm-access-sg`

## Domain scope (this wave)

### In scope

- `01.network` leaves using only foundation modules:
  - `resource-group/*`
  - `vnet/*`
  - `application-security-group/*`
  - `network-security-group/*`
  - `route/*`
  - `security-policy/*`
- `03.shared-services/log-analytics`

### Deferred

- `01.network` leaves based on subnet, DNS, resolver, gateway, rule, association modules
- `03.shared-services/shared`
- `02.storage/monitoring`
- `04.apim/workload`
- `05.ai-services/workload`
- `06.compute/*`
- `09.connectivity/*`

## Migration order

1. Reclassify shared modules in `terraform-modules` by strict policy.
2. Rewrite in-scope `01.network` leaves to foundation module contracts only.
3. Keep `03.shared-services/log-analytics` on AVM-only `log-analytics-workspace`.
4. Mark deferred leaves/modules and stop adding new references to them.

## State migration rules

- When only `source` changes and module address is stable:
  - `terraform init -upgrade`
  - `terraform plan`
- When moving resources across different addresses:
  1. backup state (`terraform state pull`)
  2. initialize target leaf
  3. import to target leaf
  4. validate with plan
  5. remove from legacy state after validation

Prefer import-based migration for transitions into AVM-backed module addresses.
