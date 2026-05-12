# Storage Monitoring (02)

`02.storage/monitoring`는 Hub 구독의 모니터링 저장소/Key Vault/Private Endpoint를 관리하는 리프입니다.

State 키: `azure/dev/02.storage/monitoring/terraform.tfstate`

## 선행 스택

1. `01.network` (Hub VNet, `hub-pep-subnet`, DNS 관련 출력)
2. (선택) `06.compute/linux-monitoring-vm` - Monitoring VM identity 연동 시

## 주요 변수

- `project_name`, `environment`, `location`, `tags`
- `hub_subscription_id`
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name`
- `monitoring_vm_identity_principal_id` (compute state 미사용 시 수동 입력)
- `key_vault_suffix` (Key Vault 이름 충돌 회피)

## 참조 모듈

- `terraform_modules/storage-account`
- `terraform_modules/key-vault`
- `terraform_modules/private-endpoint`

## 배포 명령

```bash
cd azure/dev/02.storage/monitoring
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 수정
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 수정 가이드

- 신규 저장소/PE 추가: `main.tf`에 모듈 블록 추가, 필요 변수는 `variables.tf`/`terraform.tfvars`에 반영
- Key Vault 이름/스펙 변경: `terraform.tfvars`의 `key_vault_suffix` 등 수정 후 `plan` 확인
- 기존 리소스가 Azure에 선존재하면 삭제 대신 `terraform import`로 state 동기화
