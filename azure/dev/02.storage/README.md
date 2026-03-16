# Storage

storage 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개, 하위 디렉터리(monitoring-storage)는 **모듈**로만 호출합니다.

**변수 관리 방식:**  
- **루트**: 구독 ID, backend, location, tags, **remote_state**로 얻는 컨텍스트(Hub RG 이름, 서브넷 ID, Private DNS Zone ID, Monitoring VM Identity 등)만 전달.  
- **monitoring-storage 폴더**: Key Vault 이름 접미사(`key_vault_suffix`), `enable_key_vault`, `enable_monitoring_vm` 등 **리소스 정보**는 **monitoring-storage/variables.tf 기본값**에서 관리.  
→ 신규 Monitoring Storage 세트 추가 시 **monitoring-storage 폴더 복사** → **복사한 폴더 variables.tf만 수정** → 루트 `main.tf`에 module 블록만 추가. 루트에 인스턴스별 변수 추가하지 않음.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트(`terraform-iac/`)에서 시작한다고 가정합니다.

**1단계: 스택 디렉터리로 이동 후 변수 파일 복사**
```bash
cd azure/dev/02.storage
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
에디터로 `terraform.tfvars`를 열어 다음을 본인 환경에 맞게 수정합니다.
- `hub_subscription_id` → Hub 구독 ID
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name` → Bootstrap과 동일
- Key Vault / Monitoring VM 옵션은 `monitoring-storage/variables.tf` 기본값에서 관리 (필요 시 해당 폴더만 수정)
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
cd azure/dev/02.storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수 등 (Key Vault/모니터링 옵션은 monitoring-storage 폴더 variables.tf에서 관리)
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
cd azure/dev/02.storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수, (선택) monitoring_vm_identity_principal_id 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/02.storage/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, backend_* 등. Key Vault/모니터링 옵션은 monitoring-storage 폴더 기본값. |
| 3. **remote_state: network** | Network 스택 state 조회. Hub RG 이름, 서브넷 ID, Private DNS Zone ID 등 획득. | `azure/dev/01.network/terraform.tfstate`. **선행:** network apply 완료. |
| 4. **remote_state: compute** (선택) | Monitoring VM Identity 사용 시 Compute 스택 state 조회. principal_id 획득. | `azure/dev/06.compute/terraform.tfstate`. 없으면 `var.monitoring_vm_identity_principal_id` 사용 가능. |
| 5. 구독 결정 | Key Vault·Storage·PE 등은 **Hub 구독**에 생성. | `provider.tf`: `var.hub_subscription_id` |
| 6. module "storage" 호출 | `./monitoring-storage` 실행. Key Vault, PE(pep-snet), Storage 계정 등 생성. **RG·서브넷 ID·DNS Zone**은 network remote_state에서 전달. **Key Vault 이름·enable_key_vault·enable_monitoring_vm**은 monitoring-storage 폴더 variables.tf 기본값. | network/compute remote_state outputs + monitoring-storage 폴더 기본값 |
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
(1) `monitoring-storage` 폴더 복사 → (2) **복사한 폴더의 variables.tf**에서 `key_vault_suffix`, `enable_key_vault`, `enable_monitoring_vm` 등만 수정 → (3) 루트 `main.tf`에 module 블록만 추가 → (4) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.  
(루트 `variables.tf`·`terraform.tfvars`에 인스턴스별 변수 추가하지 않음.)

- **Monitoring Storage 세트 추가**  
  1. `monitoring-storage` 디렉터리를 통째로 복사한 뒤 폴더명 변경 (예: `monitoring-storage-02`).  
  2. **복사한 폴더** `monitoring-storage-02/variables.tf`에서 `key_vault_suffix`, `enable_key_vault`, `enable_monitoring_vm` 등 **해당 인스턴스용 값만 수정**.  
  3. 루트 `main.tf`에 `module "storage_02" { source = "./monitoring-storage-02"; project_name = var.project_name; ... resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name; monitoring_vm_subnet_id = ...; pep_subnet_id = ...; private_dns_zone_ids = ...; monitoring_vm_identity_principal_id = ...; }` 블록만 추가.  
  4. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Key Vault만 추가** 등 공통 모듈에 없는 조합이 필요하면, terraform-modules 레포에 옵션 추가 후 이 스택 루트에서 `init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **Key Vault 이름 접미사·enable_key_vault·enable_monitoring_vm**  
  **monitoring-storage/variables.tf**(또는 해당 인스턴스 폴더)의 기본값을 수정한 뒤 루트에서 `terraform plan -var-file=terraform.tfvars` → `apply`.

- **remote_state로 전달되는 값(서브넷 ID 등) 변경**  
  루트 `main.tf`의 `module "storage"` 인자 또는 선행 스택(network, compute) 출력 변경 후 plan → apply.

---

## 5. 삭제 가이드 (리소스 제거)

- **Monitoring Storage 모듈 인스턴스 제거**  
  1. 루트 `main.tf`에서 해당 `module "xxx" { ... }` 블록 삭제.  
  2. 관련 변수·output 제거.  
  3. `terraform plan` → `apply`로 destroy 적용.

- **Key Vault 등만 제거**  
  해당 **monitoring-storage 폴더 variables.tf**에서 `enable_key_vault = false` 등으로 비활성화한 뒤 plan → apply.  
  모듈이 비활성화를 지원하지 않으면 모듈/리소스 제거 후 plan → apply.

- **state에서만 제거**  
  `terraform state rm 'module.xxx'` 사용.

---

## 6. 하위 모듈

| 디렉터리 | 역할 |
|----------|------|
| **monitoring-storage/** | Key Vault, Monitoring Storage, Private Endpoints (Git monitoring-storage 래핑). 리소스 정보(key_vault_suffix, enable_key_vault, enable_monitoring_vm)는 **이 폴더 variables.tf 기본값**에서 관리. 루트는 remote_state 기반 컨텍스트만 전달. |
