# Storage 배포 가이드

Hub Key Vault, Monitoring용 Storage 계정, Private Endpoint를 관리하는 스택입니다. **선행 스택:** network. **다음 스택:** shared-services.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `location`, `tags` | 공통 식별자·리전·태그 | 프로젝트 규칙 (예: `test`, `dev`, `Korea Central`) |
| `hub_subscription_id` | Hub 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `enable_key_vault` | Key Vault 생성 여부 | 기본 `true`. false면 Key Vault·PE 미생성. |
| `enable_monitoring_vm` | Monitoring VM 연동 여부 | compute 스택에서 VM 사용 시 `true`. storage만 먼저 배포 시 `false` 후 나중에 true로 변경 가능. |
| `monitoring_vm_identity_principal_id` | (선택) VM Managed Identity Principal ID | compute 스택 배포 후 output `monitoring_vm_identity_principal_id` 값. 비우면 compute 미배포 상태로 storage만 적용 가능. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/storage
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

모듈(monitoring-storage)에서 `project_name` 등으로 접두사 생성. Storage 계정 이름은 **전역 유일** 요구로 소문자·숫자만 사용.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| Storage Account | Monitoring 로그용 | 11 (기본) | `{project_name}vpnglog`, `kvlog`, `nsglog`, `vnetlog`, `vmlog`, `stgstlog`, `aoailog`, `apimlog`, `aiflog`, `acrlog`, `spkvlog` 등 + 4자리 suffix (소문자·숫자). `module.storage.azurerm_storage_account.logs` |
| Private Endpoint | Storage Blob PE | 11 (Storage 계정당 1) | `pe-{계정이름}-blob` |
| Key Vault | Hub Key Vault | 0 또는 1 | `enable_key_vault` 시. 이름: `var.key_vault_name` + 4자리 suffix (모듈 locals) |
| Private Endpoint | Key Vault PE | 0 또는 1 | `enable_key_vault` 시 `pe-{key_vault_name}` |
| Role Assignment | VM → Storage / Key Vault | 조건부 | `enable_monitoring_vm` 및 principal_id 있을 때만. |

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: Monitoring Storage 계정 1개 추가)

1. **공통 모듈(monitoring-storage)**에 새 계정 키를 지원하는 변수/로직이 있으면: 스택 `terraform.tfvars`에서 해당 변수만 추가·수정 후 plan/apply.  
2. **모듈에 해당 템플릿이 없으면:** **3.4**에 따라 terraform-modules 레포의 `monitoring-storage` 모듈에 리소스(및 변수)를 추가한 뒤, push → 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply 합니다.

### 3.2 기존 리소스 변경 (예: Key Vault 설정, 태그)

1. `terraform.tfvars` 또는 모듈 인자에서 값을 수정합니다.  
2. `terraform plan -var-file=terraform.tfvars`로 확인 후 `terraform apply -var-file=terraform.tfvars`로 적용합니다.  
3. 모듈 내부 리소스 스키마 변경이 필요하면 모듈 레포 수정 후 **3.4** 순서(upgrade → plan → apply)를 따릅니다.

### 3.3 기존 리소스 삭제

1. 제거할 리소스에 해당하는 모듈 인자 또는 `for_each` 키를 제거(또는 조건으로 비활성화)합니다.  
2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제합니다.  
3. state만 제거: `terraform state rm '주소'` (Azure 리소스는 별도 삭제).

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

1. **terraform-modules** 레포에서 해당 모듈(예: `terraform_modules/monitoring-storage`) 수정 후 커밋·push.  
2. **이 스택(storage)에서:**  
   - `terraform init -backend-config=backend.hcl -upgrade`  
   - `terraform plan -var-file=terraform.tfvars`  
   - `terraform apply -var-file=terraform.tfvars`  
3. 모듈 소스가 `ref=main`이면 `-upgrade` 시 최신 main을 사용합니다.
