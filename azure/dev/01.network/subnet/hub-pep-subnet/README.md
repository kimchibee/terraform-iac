# Hub — pep-snet (`hub-pep-subnet`)

- **State:** `azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfstate`
- **대응 서브넷:** Hub VNet의 **`pep-snet`** (Private Endpoint 등)
- **역할:** Hub `pep-snet` 기준의 보조 연결/출력 리프. 별도 보안 리프와 조합해 사용
- **선행:** [`../../vnet/hub-vnet`](../../vnet/hub-vnet) apply 완료 (`remote_state`)
- **선택 선행:** [`../application-security-group/keyvault-clients`](../application-security-group/keyvault-clients), [`../application-security-group/vm-allowed-clients`](../application-security-group/vm-allowed-clients), [`../network-security-group/keyvault-standalone`](../network-security-group/keyvault-standalone) — `use_securitygroup_prereq = true` 시 해당 state에서 ID를 읽음.

`keyvault_clients_asg_id`, `vm_allowed_clients_asg_id` 출력은 이후 compute / security 리프에서 참조할 수 있습니다.

**참고:** Hub의 나머지 서브넷 전용 리프는 `subnet/hub-gateway-subnet` 등 **동일 레벨**의 `hub-*-subnet` 폴더를 참고하세요.
