# Storage 스택 검증 결과

## 1. 작성 내용 검증 (현재 기준)

### 1.1 terraform.tfvars

| 항목 | 값 | Bootstrap 일치 | 비고 |
|------|-----|-----------------|------|
| hub_subscription_id | `f6e816bf-6df7-4fb5-953c-12507dc60879` | — | 실제 구독 ID 사용. 플레이스홀더(`xxxxxxxx-...`) 사용 시 plan/apply 시 InvalidSubscriptionId 발생. |
| backend_resource_group_name | `terraform-state-rg` | ✅ | Bootstrap `resource_group_name` 과 동일 |
| backend_storage_account_name | `tfstate7dc60879` | ✅ | Bootstrap `storage_account_name` 과 동일 |
| backend_container_name | `tfstate` | ✅ | Bootstrap `container_name` 과 동일 |
| project_name, environment, location, tags | 설정됨 | — | 정상 |
| enable_key_vault, enable_monitoring_vm | true / false | — | 정상 |

### 1.2 backend.hcl

| 항목 | 값 | 비고 |
|------|-----|------|
| resource_group_name | `terraform-state-rg` | Bootstrap과 동일 |
| storage_account_name | `tfstate7dc60879` | Bootstrap과 동일 |
| container_name | `tfstate` | Bootstrap과 동일 |
| key | `azure/dev/storage/terraform.tfstate` | Storage 스택 전용 state 키 |

→ **자기 스택 state 저장 위치**가 Bootstrap이 만든 Backend와 일치함.

### 1.3 main.tf

- `data "terraform_remote_state" "network"` / `"compute"` 에서 `var.backend_*` 사용 → 다른 스택 state 참조 위치가 terraform.tfvars와 동일 Backend로 일치.
- `module "storage"` 에 `azurerm = azurerm.hub` 전달, network output(hub_resource_group_name, hub_subnet_ids, hub_private_dns_zone_ids) 사용 → 선행 스택 의존성 정상.

### 1.4 outputs.tf

- `key_vault_id`, `key_vault_uri`, `monitoring_storage_account_ids` 출력 → rbac·connectivity 등에서 참조 가능.

---

## 2. 배포 정상 여부 확인 (터미널 로그 기준)

### 2.1 Apply 결과 (lines 381–423)

- **결과**: `Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`
- **의미**: 이미 배포된 인프라와 설정이 일치하여 변경 사항 없음. 리소스가 잘못 삭제되거나 재생성된 것이 아님.

### 2.2 Output 검증

| Output | 값 | 검증 |
|--------|-----|------|
| key_vault_id | `/subscriptions/f6e816bf-.../test-x-x-rg/.../vaults/test-hub-kvs624` | 구독·RG 일치 |
| key_vault_uri | `https://test-hub-kvs624.vault.azure.net/` | 정상 |
| monitoring_storage_account_ids | acrlog, aifoundrylog, aoailog, apimlog, kvlog, nsglog, spkvlog, stgstlog, vmlog, vnetlog, vpnglog | 11개 계정, 모두 `test-x-x-rg`·구독 `f6e816bf-...` 내 |

→ **배포 정상**. Key Vault 및 Monitoring Storage 계정·PE가 올바른 구독·리소스 그룹에 존재함.

### 2.3 주의 사항 (앞으로 실행 시)

- **반드시** `-var-file=terraform.tfvars` 를 지정하여 실행.  
  미지정 시 `hub_subscription_id` 등이 적용되지 않아 InvalidSubscriptionId 가 날 수 있음.
- `terraform.tfvars` 의 `hub_subscription_id` 는 **실제 Hub 구독 ID**로 유지할 것. 예시 값(`xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)으로 두면 plan 단계에서 실패함.

---

## 3. 요약

| 구분 | 결과 |
|------|------|
| Storage 스택 작성 내용 | ✅ 이상 없음 (Bootstrap·Backend 일치, 구독 ID 실제 값) |
| 배포 상태 | ✅ 정상 (No changes, Output 구독·RG 일치) |
| 권장 실행 방식 | `terraform plan -var-file=terraform.tfvars` / `terraform apply -var-file=terraform.tfvars` |
