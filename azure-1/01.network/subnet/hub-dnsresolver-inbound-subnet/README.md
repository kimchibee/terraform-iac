# Hub — DNSResolver-Inbound (`hub-dnsresolver-inbound-subnet`)

- **State:** `azure/dev/01.network/subnet/hub-dnsresolver-inbound-subnet/terraform.tfstate`
- **대응 서브넷:** Hub VNet의 **`DNSResolver-Inbound`** (Private DNS Resolver 인바운드 엔드포인트)
- **역할:** `vnet/hub-vnet` state에서 이 서브넷 ID를 노출합니다. Resolver·NSG 등 추가 리소스는 이 리프에서 확장하면 됩니다.
- **선행:** [`../../vnet/hub-vnet`](../../vnet/hub-vnet) apply 완료
