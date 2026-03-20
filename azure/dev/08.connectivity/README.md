# Connectivity

Hub ↔ Spoke **VNet Peering** 및 Hub 측 **진단 설정**을 관리하는 스택입니다.  
**이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다. (State 1개.)

---

## 파일·디렉터리 역할 및 배포 시 수정 위치

### 스택 루트 파일

| 파일 | 역할 | 주로 수정하는 내용 |
|------|------|-------------------|
| `main.tf` | remote_state(network, storage, shared_services), `vnet-peering` 모듈(Hub↔Spoke), `azurerm_monitor_diagnostic_setting` 등 | 피어링·진단 대상 리소스 ID 연결, 진단 로그 카테고리 추가 |
| `variables.tf` | `project_name`, 구독 ID, backend 변수 | 변수 선언 |
| `terraform.tfvars` | 실제 값 | 아래 **변수 표** 참고 |
| `backend.tf` / `backend.hcl` | 원격 state | Bootstrap과 동일 |
| `provider.tf` | `azurerm.hub`, `azurerm.spoke`(피어링은 양쪽 구독 작업 가능) | 구독 ID는 tfvars와 일치 |
| `outputs.tf` | (정의된 경우) 출력 | 다른 자동화 연동 시 |

### terraform.tfvars 변수(의미)

| 변수 | 의미 |
|------|------|
| `project_name` | 이름 접두사(모듈·리소스 네이밍과 연동되는 경우 확인) |
| `hub_subscription_id` | Hub 쪽 VNet·진단 리소스가 있는 구독 |
| `spoke_subscription_id` | Spoke 쪽 VNet이 있는 구독 |
| `backend_*` | 선행 스택 state를 읽기 위한 Storage Backend 정보 |

### 신규 리소스 추가 절차

1. **진단 설정 추가**: `main.tf`에 `azurerm_monitor_diagnostic_setting` 추가 → `target_resource_id`는 `data.terraform_remote_state.network` 등 출력 사용 → `storage_account_id`는 storage state의 monitoring Storage ID 등 → `terraform plan` / `apply`.  
2. **피어링 패턴 변경**: Git 모듈 `vnet-peering` 인자 또는 `main.tf`의 module 블록 수정 → 필요 시 terraform-modules 레포 수정 후 `init -upgrade`.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트에서 시작한다고 가정합니다. **선행:** network, storage, shared-services apply 완료.

**1단계: 변수 파일 복사**
```bash
cd azure/dev/08.connectivity
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `hub_subscription_id`, `spoke_subscription_id`, `backend_*`  
- `project_name` (필요 시)

**3단계: init / plan / apply (한 블록 통째로 복사 후 실행)**
```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 `yes` 입력.

---

## 1. 배포 방식

```bash
cd azure/dev/08.connectivity
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: project_name, 구독 ID, backend 변수 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network, storage, shared-services (Peering·진단 대상 리소스 확보).  
- **생성 대상:** Peering 2개(Hub→Spoke, Spoke→Hub) + 진단 설정 4개.  
- VNet/서브넷/NSG/VPN Gateway 자체는 **network** 스택, Storage 계정은 **storage** 스택에서 생성됩니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/08.connectivity
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, spoke_subscription_id, backend 변수, project_name 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

Connectivity 스택은 **VNet Peering**과 **진단 설정**만 생성합니다. VNet·Storage·NSG 등은 다른 스택이 만든 리소스를 **참조**합니다.

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/08.connectivity/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, backend_* 등 |
| 3. **remote_state: network** | Hub VNet ID, Spoke VNet ID. Peering의 소스·대상. | `data.terraform_remote_state.network.outputs.hub_vnet_id`, `spoke_vnet_id` 등. **선행:** network apply 완료. |
| 4. **remote_state: storage** | Storage 계정 ID. 진단 설정의 로그 저장 대상. | `data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids` 등. **선행:** storage apply 완료. |
| 5. **remote_state: shared_services** | Log Analytics 등(진단 설정 대상으로 사용 시). | `azure/dev/03.shared-services/terraform.tfstate` |
| 6. 구독 결정 | Peering은 Hub·Spoke 각각 자신의 VNet이 있는 구독에서 생성. 진단 설정은 대상 리소스가 있는 구독. | `provider.tf`: `azurerm.hub`, `azurerm.spoke` |
| 7. Peering·진단 리소스 생성 | `module "vnet_peering_hub_to_spoke"` 등. VNet ID는 network state에서, Storage/LA ID는 storage/shared_services state에서 전달. | network outputs(hub_vnet_id, spoke_vnet_id), storage outputs(storage_account_id) |
| 8. Output 기록 | (필요 시) outputs.tf. | `outputs.tf` |

**정리:** VNet ID는 **Network 스택 output**, Storage 계정 ID는 **Storage 스택 output**에서만 가져옴. 이 스택은 리소스를 새로 만들지 않고 **기존 리소스 간 연결·설정**만 추가합니다.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state" "network"**, **"storage"**, **"shared_services"** 실행 → **module "vnet_peering_*"**, **azurerm_monitor_diagnostic_setting** 등에서 해당 outputs 참조. 6. Git 모듈(terraform-modules vnet-peering 등). 7. **outputs.tf** (있는 경우)

**의존성:** main.tf → remote_state(network, storage, shared_services) → **network, storage, shared-services 선배포 필수.**

---

## 3. 추가 가이드 (신규 리소스 추가)

**공통 절차 (이 스택은 하위 모듈 디렉터리 없음)**  
신규 리소스 추가 시: 루트 `main.tf`에 `resource` 또는 `module` 블록 추가 (필요 시 `variables.tf`·`terraform.tfvars` 반영) → **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **진단 설정 1개 추가**  
  1. 루트 `main.tf`에 `azurerm_monitor_diagnostic_setting` 리소스 블록 추가.  
  2. `target_resource_id`는 `data.terraform_remote_state.network.outputs.*` 또는 `data.terraform_remote_state.storage.outputs.*`로 참조.  
  3. `storage_account_id`는 `data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["xxx"]` 등 사용.  
  4. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`로 반영.

- **Peering 추가**  
  vnet-peering 모듈에 옵션이 있으면 루트 `main.tf`에 module 블록 추가 + 필요 시 `variables.tf`·`terraform.tfvars` 반영 후 **이 스택 루트에서** plan → apply.  
  모듈에 없으면 terraform-modules 레포에 반영 후 `init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **Peering 옵션·진단 로그 카테고리 등**  
  `main.tf` 또는 해당 모듈 인자에서 옵션 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- 모듈 인자 변경 시, 모듈(terraform-modules) 쪽에서 해당 변수/인자를 지원하는지 확인합니다.

---

## 5. 삭제 가이드 (리소스 제거)

- **Peering 또는 진단 설정 제거**  
  1. 제거할 `resource` 또는 `module` 블록을 `main.tf`에서 삭제(또는 주석 처리).  
  2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.

- **state에서만 제거**  
  `terraform state rm '주소'` 사용 (Azure 리소스는 유지할 때만).

---

## 6. 공통 모듈 수정 후 반영

terraform-modules 레포에서 vnet-peering 등 모듈 수정 후:

1. 이 스택 디렉터리에서 `terraform init -backend-config=backend.hcl -upgrade`  
2. `terraform plan -var-file=terraform.tfvars`  
3. `terraform apply -var-file=terraform.tfvars`  

`ref=main` 사용 시 `-upgrade`로 최신 main을 가져옵니다.
