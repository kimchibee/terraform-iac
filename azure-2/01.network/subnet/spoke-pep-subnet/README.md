# Spoke — pep-snet (`spoke-pep-subnet`)

- **State:** `azure/dev/01.network/subnet/spoke-pep-subnet/terraform.tfstate`
- **대응 서브넷:** Spoke VNet의 **`pep-snet`** (Private Endpoint 등, `spoke-vnet` 모듈 기본과 동일 키)
- **역할:** `vnet/spoke-vnet` state에서 이 서브넷 ID를 노출합니다. 추가 보안 리소스는 `network-security-group/*` 구조로 별도 분리합니다.
- **선행:** [`../../vnet/spoke-vnet`](../../vnet/spoke-vnet) apply 완료
