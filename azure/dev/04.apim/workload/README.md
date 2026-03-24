# APIM

API Management(Internal VNet)를 Spoke의 apim-snet에 배포하는 스택입니다.  
**이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다. (State 1개, 하위 모듈 디렉터리 없음.)

---

## 파일·디렉터리 역할 및 배포 시 수정 위치

### 스택 루트 파일

| 파일 | 역할 | 주로 수정하는 내용 |
|------|------|-------------------|
| `main.tf` | remote_state(network, storage, shared_services), Git 모듈 `spoke-workloads` 호출(APIM 파트) | APIM 관련 인자·모듈 옵션 |
| `locals.tf` | (있는 경우) 이름·로컬 계산 | 네이밍 규칙 변경 시 |
| `variables.tf` | 변수 선언·설명 | 새 변수 추가 시 |
| `terraform.tfvars` | 실제 배포 값 | 아래 **terraform.tfvars 변수 표** 참고 |
| `backend.tf` / `backend.hcl` | 원격 state | Bootstrap·`generate-backend-hcl.sh`와 동일 값 |
| `provider.tf` | 기본 provider = **Spoke 구독** | `spoke_subscription_id`와 연동 |
| `outputs.tf` | `apim_id` 등 | rbac·다른 스택 참조 |

### terraform.tfvars에서 다루는 변수(의미)

| 변수 | 의미 |
|------|------|
| `project_name`, `environment`, `location`, `tags` | 리소스 접두사·환경·리전·태그 |
| `spoke_subscription_id` | APIM이 생성될 **Spoke 구독 ID**(provider 기본 구독) |
| `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name` | remote_state로 읽을 **state Blob 위치**(Bootstrap과 동일) |
| `enable_spoke_to_hub_peering` | Spoke→Hub 피어링을 이 모듈에서 만들지 여부. **connectivity 스택에서 피어링 관리 시 `false`** |
| `enable_private_dns_zone_links` | Private DNS Zone Link를 여기서 만들지 여부. **network 스택에서 관리 시 `false`** |
| `enable_pep_nsg` | Spoke PEP용 NSG를 여기서 만들지 여부. **network 스택에서 NSG 관리 시 `false`** |
| `apim_sku_name` | APIM SKU(예: `Developer_1`, `Premium_1`). 용량·가격에 영향 |
| `apim_publisher_name`, `apim_publisher_email` | APIM 개발자 포털에 표시되는 게시자 정보 |

### 신규 리소스·설정 추가 절차

1. **모듈 인자로 가능한 옵션**: `variables.tf`에 변수 추가 → `terraform.tfvars`에 값 → `main.tf`에서 `module` 인자로 전달 → `terraform plan` / `apply`.  
2. **terraform-modules에만 있는 기능**: 레포 수정 후 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan/apply.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트에서 시작한다고 가정합니다. **선행:** network, storage, shared-services apply 완료.

**1단계: 변수 파일 복사**
```bash
cd azure/dev/04.apim
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `spoke_subscription_id`, `backend_*`  
- `apim_sku_name`, `apim_publisher_name`, `apim_publisher_email`  
- (선택) `enable_spoke_to_hub_peering`, `enable_private_dns_zone_links`, `enable_pep_nsg` — 네트워크 스택과 역할이 겹치지 않게 유지

**3단계: init / plan / apply (한 블록 통째로 복사 후 실행)**  
(배포에 30분~1시간 소요될 수 있음.)
```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 `yes` 입력.

---

## 1. 배포 방식

```bash
cd azure/dev/04.apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: spoke_subscription_id, backend 변수, apim_sku_name, apim_publisher_name/email 등
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
cd azure/dev/04.apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: spoke_subscription_id, backend 변수, apim_sku_name, apim_publisher_name/email 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/04.apim/workload/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, apim_sku_name, backend_* 등 |
| 3. **remote_state: network** | Spoke VNet ID, apim-snet 서브넷 ID 등. APIM을 배치할 네트워크 정보. | Hub: `azure/dev/01.network/vnet/hub-vnet/terraform.tfstate`, Spoke: `azure/dev/01.network/vnet/spoke-vnet/terraform.tfstate`. **선행:** Hub·Spoke network apply 완료. |
| 4. **remote_state: storage** | Monitoring Storage 등 (필요 시). | `azure/dev/02.storage/monitoring/terraform.tfstate` |
| 5. **remote_state: shared_services** | Log Analytics Workspace ID 등. | `azure/dev/03.shared-services/shared/terraform.tfstate`. **선행:** shared-services apply 완료. |
| 6. 구독 결정 | APIM 리소스는 **Spoke 구독**에 생성(Internal VNet). | `provider.tf`: 기본 provider = `var.spoke_subscription_id` |
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

## 6. 참고

- OpenAI, AI Foundry는 **ai-services** 스택에서 생성. 이 스택에는 나오면 안 됨.
- VNet/서브넷은 **network** 스택에서 관리.
- 이 스택은 하위 모듈 디렉터리 없이 루트에서 Git 모듈(spoke-workloads)만 참조합니다.
