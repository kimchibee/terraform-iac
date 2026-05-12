# Spoke — apim-snet (`spoke-apim-subnet`)

- **State:** `azure/dev/01.network/subnet/spoke-apim-subnet/terraform.tfstate`
- **대응 서브넷:** Spoke VNet의 **`apim-snet`** (기본 `terraform.tfvars.example` / `variables.tf` 기준)
- **역할:** `vnet/spoke-vnet` state에서 이 서브넷 ID를 노출합니다. 서브넷 이름을 바꾼 경우 `main.tf`의 `local.subnet_key`를 동일하게 맞추면 됩니다.
- **선행:** [`../../vnet/spoke-vnet`](../../vnet/spoke-vnet) apply 완료
