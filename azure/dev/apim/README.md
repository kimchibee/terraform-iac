# APIM 배포 가이드

API Management(Internal VNet)를 Spoke의 apim-snet에 배포하는 스택입니다. **선행 스택:** shared-services. **다음 스택:** ai-services. (배포에 30분~1시간 소요될 수 있음)

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `location`, `tags` | 공통 식별자·리전·태그 | 프로젝트 규칙 (예: `test`, `dev`, `Korea Central`) |
| `spoke_subscription_id` | Spoke 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `apim_sku_name` | APIM SKU | 예: `Developer_1`, `Basic_1`, `Standard_1`, `Premium_1` |
| `apim_publisher_name`, `apim_publisher_email` | APIM 게시자 정보 | 관리자 이름·이메일 (APIM Portal에 표시) |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/apim
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

APIM은 **spoke-workloads** 모듈을 사용하며, **apim_name**이 설정된 경우에만 APIM·APIM NSG가 생성됩니다. VNet/서브넷은 network 스택에서 관리.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| NSG | apim-snet용 NSG | 1 | `{project_name}-apim-nsg` (Spoke RG) |
| Subnet ↔ NSG | apim-snet 연동 | 1 | apim-snet에 위 NSG 연결 |
| API Management | APIM 서비스 | 1 | `{apim_name}-{4자리 suffix}` (예: test-x-x-apim-d0o4). Internal VNet, apim-snet 사용. |
| Diagnostic Setting | APIM 진단 | 1 | `{apim_name}-diag` → Log Analytics. |
| (선택) NSG | pep-snet | 0 또는 1 | `enable_pep_nsg` 시 `{project_name}-spoke-pep-nsg` |

※ OpenAI, AI Foundry는 **ai-services** 스택에서 생성. 이 스택에는 나오면 안 됨.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: APIM에 추가 설정)

1. **모듈(spoke-workloads)**에 해당 리소스/인자가 있으면: 스택에서 변수만 추가 후 plan/apply.  
2. **모듈에 없는 리소스:** **3.4**에 따라 terraform-modules 레포의 spoke-workloads(또는 전용 모듈)에 템플릿 추가 후 push → 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply.

### 3.2 기존 리소스 변경 (예: APIM SKU, 게시자 정보, VM 사이즈 아님)

1. `terraform.tfvars`에서 `apim_sku_name`, `apim_publisher_name`, `apim_publisher_email` 등 수정.  
2. `terraform plan -var-file=terraform.tfvars`로 확인 후 `terraform apply -var-file=terraform.tfvars`로 적용.  
3. APIM은 일부 속성 변경 시 재생성될 수 있으므로 plan 결과를 반드시 확인합니다.

### 3.3 기존 리소스 삭제

1. APIM 제거: 모듈에서 apim_name을 비우거나, 스택에서 apim 모듈 호출 제거(또는 count=0).  
2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.  
3. state만 제거: `terraform state rm '주소'` (Azure 리소스는 별도 삭제).

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

1. **terraform-modules** 레포에서 **spoke-workloads** (또는 해당 모듈) 수정 후 커밋·push.  
2. **이 스택(apim)에서:**  
   - `terraform init -backend-config=backend.hcl -upgrade`  
   - `terraform plan -var-file=terraform.tfvars`  
   - `terraform apply -var-file=terraform.tfvars`  
3. 모듈 소스가 `ref=main`이면 `-upgrade` 시 최신 main을 사용합니다.
