# Hub — Azure Firewall Policy (+ Firewall)

- **State:** `azure/dev/01.network/security-group/security-policy/hub-sg-policy-default/terraform.tfstate`
- **선행:** [`../../vnet/hub-vnet`](../../vnet/hub-vnet) — `AzureFirewallSubnet` 및 Hub RG 필요 (`remote_state`)
- **출력:** `hub_firewall_policy_id`, `hub_firewall_private_ip` 등 — UDR·다른 스택에서 `terraform_remote_state`로 연동

`deploy_azure_firewall = false`로 정책만 둘 수 있습니다(PIP·Firewall 리소스 없음).

Spoke 쪽 정책은 [`../spoke-sg-policy-default`](../spoke-sg-policy-default) 리프를 참고하세요.
