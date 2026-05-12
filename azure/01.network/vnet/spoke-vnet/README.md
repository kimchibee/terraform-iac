# Spoke — VNet 리프

- **State:** `azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate`
- **선행:** [`../hub-vnet`](../hub-vnet) — Hub VNet state (`remote_state`)
- **이 디렉터리의 `main.tf`만**으로 `terraform apply` 합니다. `spoke-vnet` 모듈은 terraform-modules Git/로컬 소스를 참조합니다.
- Spoke 주소·서브넷·접미사는 **이 리프**의 [`variables.tf`](variables.tf) 기본값에서 관리합니다.
