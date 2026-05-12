# Hub — AzureFirewallManagementSubnet (`hub-azurefirewall-management-subnet`)

- **State:** `azure/dev/01.network/subnet/hub-azurefirewall-management-subnet/terraform.tfstate`
- **대응 서브넷:** Hub VNet의 **`AzureFirewallManagementSubnet`** (Basic SKU 등 관리용)
- **역할:** `vnet/hub-vnet` state에서 이 서브넷 ID를 노출합니다.
- **선행:** [`../../vnet/hub-vnet`](../../vnet/hub-vnet) apply 완료
