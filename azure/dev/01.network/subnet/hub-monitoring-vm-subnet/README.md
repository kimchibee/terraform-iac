# Hub — Monitoring-VM-Subnet (`hub-monitoring-vm-subnet`)

- **State:** `azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfstate`
- **대응 서브넷:** Hub VNet의 **`Monitoring-VM-Subnet`**
- **역할:** `vnet/hub-vnet` state에서 이 서브넷 ID를 노출합니다. 모니터링 VM·NSG 등은 이 리프에서 확장하면 됩니다.
- **선행:** [`../../vnet/hub-vnet`](../../vnet/hub-vnet) apply 완료
