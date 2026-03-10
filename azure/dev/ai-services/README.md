# AI-Services 배포 가이드

Azure OpenAI, AI Foundry(ML Workspace, ACR, Storage, Application Insights), Spoke 쪽 Private Endpoint 등을 관리하는 스택입니다. **선행 스택:** apim. **다음 스택:** compute.  
※ **APIM·apim-snet용 NSG**는 apim 스택 리소스이므로 이 스택 plan에 나오면 안 됩니다.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/ai-services
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
| `openai_sku` | Azure OpenAI 요금제 | 예: `S0`. 쿼터 승인 필요. |
| `openai_deployments` | 배포할 모델 목록 | 쿼터 승인 전에는 `[]`. 승인 후 예시는 `terraform.tfvars.example` 또는 `docs/AZURE-OPENAI-QUOTA-AND-MODELS.md` 참고. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/ai-services
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

**spoke-workloads** 모듈 사용. **apim_name = ""** 이므로 APIM·APIM NSG는 생성되지 않습니다. OpenAI·AI Foundry 관련만 생성.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| Cognitive Account | Azure OpenAI | 1 | `{project_name}-x-x-aoai{4자리}` (예: test-x-x-aoaik0kj) |
| Cognitive Deployment | 모델 배포 | openai_deployments 길이만큼 | 배포 name/model_name 등은 변수로 지정 |
| Private Endpoint | OpenAI PE | 1 | `pe-test-x-x-aoai` 등 |
| Diagnostic Setting | OpenAI 진단 | 1 | `{name}-diag` → Log Analytics |
| Storage Account | AI Foundry용 | 1 | `{project_name}x-x-aifoundryst{4자리}` (소문자) |
| Application Insights | AI Foundry용 | 1 | `{project_name}-x-x-aifoundry-ai` 등 |
| Container Registry | AI Foundry용 | 1 | `{project_name}x-x-aifoundryacr{4자리}` (소문자) |
| Machine Learning Workspace | AI Foundry | 1 | `{project_name}-x-x-aifoundry` |
| Private Endpoint | AI Foundry / Storage | 2 | `pe-test-x-x-aifoundry`, `pe-test-x-x-aifoundry-storage` 등 |
| (선택) NSG | pep-snet | 0 또는 1 | `enable_pep_nsg` 시 `{project_name}-spoke-pep-nsg` |

※ `module.ai_services.azurerm_network_security_group.apim` / `azurerm_api_management.main` 이 plan에 있으면 **다른 스택(apim) 리소스**이므로 모듈 ref 또는 apim_name 설정을 확인하세요.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: OpenAI 모델 배포 1개 추가)

1. **모듈에 이미 지원되는 경우:** `terraform.tfvars`의 `openai_deployments`에 항목 추가 후 plan/apply.  
2. **모듈에 없는 리소스 타입:** **3.4**에 따라 terraform-modules 레포의 spoke-workloads(또는 해당 모듈)에 템플릿 추가 후 push → 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply.

### 3.2 기존 리소스 변경 (예: 모델 버전, capacity, SKU)

1. `terraform.tfvars`에서 `openai_deployments`, `openai_sku` 등 수정.  
2. `terraform plan`으로 변경 내용 확인 후 `apply`로 적용.  
3. ML Workspace 등 일부 리소스는 변경 시 재생성될 수 있으므로 plan 결과를 확인합니다.

### 3.3 기존 리소스 삭제

1. 제거할 리소스에 해당하는 변수(예: `openai_deployments`에서 항목 제거) 또는 모듈 인자를 수정.  
2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.  
3. state만 제거: `terraform state rm '주소'`.

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

1. **terraform-modules** 레포에서 **spoke-workloads** (또는 해당 모듈) 수정 후 커밋·push.  
2. **이 스택(ai-services)에서:**  
   - `terraform init -backend-config=backend.hcl -upgrade`  
   - `terraform plan -var-file=terraform.tfvars`  
   - `terraform apply -var-file=terraform.tfvars`  
3. 모듈 소스가 `ref=main`이면 `-upgrade` 시 최신 main을 사용합니다.
