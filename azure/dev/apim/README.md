# APIM

API Management(Internal VNet)를 Spoke의 apim-snet에 배포하는 스택입니다.  
**이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다. (State 1개, 하위 모듈 디렉터리 없음.)

---

## 1. 배포 방식

```bash
cd azure/dev/apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, apim_sku_name, apim_publisher_name/email 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network, storage, shared-services.  
- **다음 스택:** ai-services. (배포에 30분~1시간 소요될 수 있음.)

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, spoke_subscription_id, backend 변수, apim_sku_name, apim_publisher_name/email 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/apim/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, apim_sku_name, backend_* 등 |
| 3. **remote_state: network** | Spoke VNet ID, apim-snet 서브넷 ID 등. APIM을 배치할 네트워크 정보. | `azure/dev/network/terraform.tfstate`. **선행:** network apply 완료. |
| 4. **remote_state: storage** | Monitoring Storage 등 (필요 시). | `azure/dev/storage/terraform.tfstate` |
| 5. **remote_state: shared_services** | Log Analytics Workspace ID 등. | `azure/dev/shared-services/terraform.tfstate`. **선행:** shared-services apply 완료. |
| 6. 구독 결정 | APIM 리소스는 **Spoke 구독**에 생성(Internal VNet). | `provider.tf`: `azurerm.spoke` → `var.spoke_subscription_id` (또는 hub에 배치 시 hub_subscription_id) |
| 7. module "apim" 호출 | APIM 리소스 생성. 서브넷 ID·VNet ID는 network state에서 전달. | `data.terraform_remote_state.network.outputs.spoke_vnet_id`, `spoke_subnet_ids["apim-snet"]` 등, shared_services output |
| 8. Output 기록 | `apim_id` 등. ai-services·rbac가 참조. | `outputs.tf` |

**정리:** VNet/서브넷 ID는 **Network 스택 output**, Log Analytics 등은 **Shared Services 스택 output**에서만 가져옴.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state" "network"**, **"storage"**, **"shared_services"** 실행 → **module "apim"** 호출 시 해당 outputs 전달. 6. (모듈이 Git 참조 시) **terraform-modules** 레포의 apim 관련 모듈. 7. **outputs.tf**

**의존성:** main.tf → remote_state(network, storage, shared_services) → **network, shared-services 선배포 필수.** storage는 모듈에서 사용 시 선배포.

---

## 3. 추가 가이드 (신규 리소스·설정 추가)

**공통 절차 (이 스택은 하위 모듈 디렉터리 없음)**  
신규 리소스·설정 추가 시: 루트 `main.tf`에 module 인자 또는 resource 추가 + 루트 `variables.tf`에 변수 추가 + `terraform.tfvars`에 값 설정 → **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **APIM에 추가 설정·리소스**  
  - spoke-workloads 모듈에 해당 인자가 있으면: 루트 `variables.tf`·`terraform.tfvars`에 변수·값 추가 후 **이 스택 루트에서** plan → apply.  
  - 모듈에 없으면: terraform-modules 레포에 반영 후 push → 이 스택 루트에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply.

- **공통 모듈 수정 후 반영**  
  이 스택 루트에서 `terraform init -upgrade` 후 plan → apply. (`ref=main` 사용 시 최신 main 반영.)

---

## 4. 변경 가이드 (기존 리소스 수정)

- **APIM SKU, 게시자 정보 등**  
  `terraform.tfvars`에서 `apim_sku_name`, `apim_publisher_name`, `apim_publisher_email` 등 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- APIM은 일부 속성 변경 시 **재생성**될 수 있으므로 plan 결과를 반드시 확인한 뒤 적용합니다.

---

## 5. 삭제 가이드 (리소스 제거)

- **APIM 제거**  
  1. 모듈에서 apim_name을 비우거나, 루트 `main.tf`의 apim 모듈 호출을 제거(또는 count=0 등으로 비활성화).  
  2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.

- **state에서만 제거**  
  `terraform state rm '주소'` 사용 (Azure 리소스는 별도 삭제).

---

## 5. 참고

- OpenAI, AI Foundry는 **ai-services** 스택에서 생성. 이 스택에는 나오면 안 됨.
- VNet/서브넷은 **network** 스택에서 관리.
