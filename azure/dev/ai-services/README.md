# AI Services

Azure OpenAI, AI Foundry(ML Workspace, ACR, Storage, Application Insights), Spoke 쪽 Private Endpoint 등을 관리하는 스택입니다.  
**이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다. (State 1개, 하위 모듈 디렉터리 없음.)

---

## 1. 배포 방식

```bash
cd azure/dev/ai-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, openai_sku, openai_deployments 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network, storage, shared-services.  
- **다음 스택:** compute.  
- **참고:** APIM·apim-snet용 NSG는 apim 스택 리소스이므로 이 스택 plan에 나오면 안 됩니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/ai-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, spoke_subscription_id, backend 변수, openai_sku, openai_deployments 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/ai-services/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, openai_sku, openai_deployments, backend_* 등 |
| 3. **remote_state: network** | Hub/Spoke VNet·서브넷·Private DNS Zone ID. OpenAI·PE·ML Workspace 배치용. | `azure/dev/network/terraform.tfstate`. **선행:** network apply 완료. |
| 4. **remote_state: storage** | Key Vault, Storage 계정 ID 등. | `azure/dev/storage/terraform.tfstate` |
| 5. **remote_state: shared_services** | Log Analytics 등. | `azure/dev/shared-services/terraform.tfstate` |
| 6. 구독 결정 | OpenAI·Key Vault 등은 **Hub 구독**, Spoke 쪽 PE 등은 **Spoke 구독**에 생성될 수 있음. | `provider.tf`: hub / spoke 구독 변수 |
| 7. 모듈 호출 | OpenAI, AI Foundry(ML Workspace, ACR, Storage), Spoke PE 등 생성. 서브넷 ID·DNS Zone·RG는 network/storage/shared_services state에서 전달. | 각 remote_state outputs → 모듈 인자 |
| 8. Output 기록 | `openai_id`, `key_vault_id`, `storage_account_id` 등. rbac 등이 참조. | `outputs.tf` |

**정리:** VNet/서브넷/Private DNS Zone은 **Network 스택 output**, Storage·Key Vault 관련은 **Storage/Shared Services 스택 output**에서 가져옴.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state" "network"**, **"storage"**, **"shared_services"** 등 실행 → 모듈 호출 시 해당 outputs 전달. 6. 루트 또는 Git 모듈(terraform-modules) 내 리소스 정의. 7. **outputs.tf**

**의존성:** main.tf → remote_state(network, storage, shared_services) → **network, shared-services 선배포 필수.** storage는 Key Vault 등 사용 시 선배포.

---

## 3. 추가 가이드 (신규 리소스·모델 추가)

**공통 절차 (이 스택은 하위 모듈 디렉터리 없음)**  
신규 리소스·모델 추가 시: 루트 `variables.tf`에 변수 추가 + `terraform.tfvars`에 값 설정(또는 루트 `main.tf`에 resource/module 인자 반영) → **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **OpenAI 모델 배포 추가**  
  루트 `terraform.tfvars`의 `openai_deployments`에 항목 추가 후 **이 스택 루트에서** plan → apply.  
  쿼터 승인 전에는 `openai_deployments = []`로 두고 배포 가능.

- **모듈에 없는 리소스 타입**  
  terraform-modules 레포에 템플릿 추가 후 push → 이 스택 루트에서 `terraform init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **모델 버전, capacity, SKU 등**  
  `terraform.tfvars`에서 `openai_deployments`, `openai_sku` 등 수정 후  
  `terraform plan`으로 변경 내용 확인 → `apply`로 적용.

- ML Workspace 등 일부 리소스는 변경 시 **재생성**될 수 있으므로 plan 결과를 확인한 뒤 적용합니다.

---

## 5. 삭제 가이드 (리소스 제거)

- **배포/리소스 제거**  
  1. 제거할 리소스에 해당하는 변수(예: `openai_deployments`에서 항목 제거) 또는 모듈 인자 수정.  
  2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.

- **state에서만 제거**  
  `terraform state rm '주소'` 사용.

---

## 5. 참고

- `module.ai_services.azurerm_network_security_group.apim` / `azurerm_api_management.main` 이 plan에 있으면 **apim** 스택 리소스이므로 모듈 ref 또는 apim_name 설정을 확인하세요.
