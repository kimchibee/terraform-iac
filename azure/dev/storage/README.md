# Storage

storage 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개, 하위 디렉터리(monitoring-storage)는 **모듈**로만 호출합니다.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트(`terraform-iac/`)에서 시작한다고 가정합니다.

**1단계: 스택 디렉터리로 이동 후 변수 파일 복사**
```bash
cd azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
에디터로 `terraform.tfvars`를 열어 다음을 본인 환경에 맞게 수정합니다.
- `hub_subscription_id` → Hub 구독 ID
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name` → Bootstrap과 동일
- `enable_key_vault` → Key Vault 생성 여부 (true/false)
- Monitoring VM Identity 사용 시: `monitoring_vm_identity_principal_id` 또는 compute 스택 먼저 적용 후 비워두기(remote_state로 자동 조회)

**3단계: init / plan / apply (한 블록 통째로 복사 후 실행)**
```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 프롬프트에 `yes` 입력.

---

## 1. 배포 방식

```bash
cd azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, enable_key_vault 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network. (compute는 선택: Monitoring VM Identity 사용 시 compute 선배포.)  
- **다음 스택:** shared-services, apim, ai-services, rbac, connectivity 등이 이 스택 state를 참조할 수 있습니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수, enable_key_vault, (선택) monitoring_vm_identity_principal_id 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/storage/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, enable_key_vault, backend_* 등 |
| 3. **remote_state: network** | Network 스택 state 조회. Hub RG 이름, 서브넷 ID, Private DNS Zone ID 등 획득. | `azure/dev/network/terraform.tfstate`. **선행:** network apply 완료. |
| 4. **remote_state: compute** (선택) | Monitoring VM Identity 사용 시 Compute 스택 state 조회. principal_id 획득. | `azure/dev/compute/terraform.tfstate`. 없으면 `var.monitoring_vm_identity_principal_id` 사용 가능. |
| 5. 구독 결정 | Key Vault·Storage·PE 등은 **Hub 구독**에 생성. | `provider.tf`: `var.hub_subscription_id` |
| 6. module "storage" 호출 | `./monitoring-storage` 실행. Key Vault, PE(pep-snet), Storage 계정 등 생성. **서브넷 ID·RG·DNS Zone**은 network remote_state에서 전달. | `data.terraform_remote_state.network.outputs.hub_resource_group_name`, `hub_subnet_ids["Monitoring-VM-Subnet"]`, `hub_subnet_ids["pep-snet"]`, `hub_private_dns_zone_ids`, `data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id`(또는 var) |
| 7. Output 기록 | `key_vault_id`, `hub_resource_group_name` 등. rbac·다른 스택이 참조. | `outputs.tf` |

**정리:** VNet/서브넷 ID·RG 이름은 **Network 스택 output**에서만 가져옴. Monitoring VM Identity는 **Compute 스택 output** 또는 변수로 지정.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** (init 시)  
2. **provider.tf**  
3. **variables.tf**  
4. **terraform.tfvars**  
5. **main.tf** — **data "terraform_remote_state" "network"**, **data "terraform_remote_state" "compute"** 실행 → **module "storage"** 호출 시 network·compute outputs 전달.  
6. **./monitoring-storage/** — Git 모듈(terraform-modules) 참조.  
7. **outputs.tf**

**의존성:** main.tf → remote_state(network, compute) → network/outputs, compute/outputs 사용 → ./monitoring-storage 참조. **network 선배포 필수**, compute는 Monitoring VM Identity 사용 시 선배포 권장.

---

## 3. 추가 가이드 (신규 리소스 추가)

**공통 절차 (신규 인스턴스 추가 시)**  
(1) 예시 디렉터리 복사 → (2) 필요 시 새 디렉터리 내 기본값 수정 → (3) 루트 `main.tf`에 module 블록 추가 → (4) 루트 `variables.tf`에 변수 추가 → (5) `terraform.tfvars`에 값 설정 → (6) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Monitoring Storage 세트 추가**  
  1. `monitoring-storage` 디렉터리를 복사해 새 이름 생성 (예: `monitoring-storage-02`). **(복사 후 수정 가이드:** `monitoring-storage/main.tf` 상단 주석 참고.)  
  2. 루트 `main.tf`에 `module "storage_02" { source = "./monitoring-storage-02"; ... }` 추가.  
  3. 루트 `variables.tf`에 해당 모듈용 변수 정의.  
  4. `terraform.tfvars`에 값 설정.  
  5. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Key Vault만 추가** 등 공통 모듈에 없는 조합이 필요하면, terraform-modules 레포에 옵션 추가 후 이 스택 루트에서 `init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **설정 변경**  
  `terraform.tfvars`에서 `enable_key_vault`, `enable_monitoring_vm` 등 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- **모듈 인자 변경**  
  루트 `main.tf`의 `module "storage"` 인자 또는 하위 모듈/공통 모듈 수정 후 plan → apply.

---

## 5. 삭제 가이드 (리소스 제거)

- **Monitoring Storage 모듈 인스턴스 제거**  
  1. 루트 `main.tf`에서 해당 `module "xxx" { ... }` 블록 삭제.  
  2. 관련 변수·output 제거.  
  3. `terraform plan` → `apply`로 destroy 적용.

- **Key Vault 등만 제거**  
  변수로 비활성화(`enable_key_vault = false` 등)할 수 있으면 그렇게 한 뒤 plan → apply.  
  모듈이 비활성화를 지원하지 않으면 모듈/리소스 제거 후 plan → apply.

- **state에서만 제거**  
  `terraform state rm 'module.xxx'` 사용.

---

## 6. 하위 모듈

| 디렉터리 | 역할 |
|----------|------|
| **monitoring-storage/** | Key Vault, Monitoring Storage, Private Endpoints (Git monitoring-storage 래핑) |
