# Spoke — Azure Firewall Policy (+ 선택: Azure Firewall)

- **State:** `azure/dev/01.network/security-group/security-policy/spoke-sg-policy-default/terraform.tfstate`
- **선행:** [`../../vnet/spoke-vnet`](../../vnet/spoke-vnet) — Spoke RG·VNet (`remote_state`)
- **기본:** `deploy_azure_firewall = false` — **Firewall Policy**만 Spoke RG에 두고, 트래픽은 보통 Hub 방화벽으로 보냅니다. Spoke에 전용 Azure Firewall VM이 필요하면 `true`로 두고, [`../../vnet/spoke-vnet`](../../vnet/spoke-vnet) 쪽 `spoke_subnet_ids`에 `firewall_subnet_key`(기본 `AzureFirewallSubnet`)에 해당하는 서브넷을 정의해야 합니다.
