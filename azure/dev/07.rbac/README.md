# RBAC

Monitoring VM(compute 스택)의 Managed Identity에 Hub/Spoke 리소스 접근용 **역할 할당**을 부여하고, **시나리오 1: 그룹 기반 리소스 권한**을 **폴더 단위**로 관리하는 스택입니다.  
State 1개(`azure/dev/07.rbac/terraform.tfstate`), 그룹별 하위 디렉터리(admin-group, ai-developer-group 등)는 **모듈**로만 호출합니다. **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.

**변수 관리 방식 (그룹 모듈)**  
- **루트**: 그룹 Object ID, scope(구독/RG ID), 멤버 Object ID 목록 등 **컨텍스트**만 전달. (remote_state로 scope_id를 쓰는 경우 루트에서 전달.)  
- **admin-group / ai-developer-group 폴더**: **역할 이름**(`role_definition_name`, `spoke_rg_role_definition_name`)은 **해당 폴더 variables.tf 기본값**에서 관리.  
→ 신규 그룹 추가 시 **해당 그룹 폴더 복사** → **복사한 폴더 variables.tf**에서 역할 이름 등만 수정 → 루트 `main.tf`에 module 블록 + 루트 `variables.tf`·`terraform.tfvars`에 **그룹/scope/멤버 변수만** 추가.

---

## 파일·디렉터리 역할 및 배포 시 수정 위치

### 스택 루트 파일

| 파일 | 역할 | 주로 수정하는 내용 |
|------|------|-------------------|
| `main.tf` | remote_state(compute, network, storage, ai_services, apim), `azurerm_role_assignment`, 그룹 모듈 호출 | 역할 할당 블록 추가·제거, 그룹 모듈 연결 |
| `variables.tf` | 루트 변수 선언 | `enable_*`, 그룹 Object ID·scope·멤버, `iam_role_assignments` 등 |
| `terraform.tfvars` | 실제 값 | **대부분의 권한·멤버십 값은 여기서만 변경** |
| `backend.tf` / `backend.hcl` | 원격 state | Bootstrap 연동 |
| `provider.tf` | `azurerm`·`azuread` | 구독·테넌트 인증 |
| `outputs.tf` | (정의 시) 출력 | |

### 하위 디렉터리(그룹·멤버 모듈)

| 디렉터리 | 역할 | 수정 원칙 |
|----------|------|-----------|
| `admin-group/`, `ai-developer-group/` 등 | 그룹에 RBAC 역할 부여 | **역할 이름**은 각 폴더 `variables.tf` **기본값** |
| `admin-group/admin-users/` 등 | Entra ID 그룹 **멤버십** | 멤버 목록은 **루트 `terraform.tfvars`**의 `*_member_object_ids` |

### terraform.tfvars 변수(의미) 예시

| 변수 | 의미 |
|------|------|
| `enable_monitoring_vm_roles` | Monitoring VM MI에 대해 사전 정의된 역할 할당을 켤지 여부 |
| `enable_key_vault_roles` | Key Vault 관련 역할 할당 켤지 여부 |
| `admin_group_object_id` / `admin_group_scope_id` / `admin_group_member_object_ids` | 관리자 그룹 ID, 역할 부여 범위(RG/구독 ID), 멤버 Object ID 목록 |
| `ai_developer_group_*` | AI 개발자 그룹용 동일 패턴 |
| `iam_role_assignments` | (시나리오 2) 임의 principal·역할·scope_ref 조합 목록. `scope_ref`는 코드에 정의된 키(`storage_key_vault_id`, `apim_id` 등) |

### 신규 역할·그룹 추가 절차

1. **Monitoring VM에 역할 하나 더**: 루트 `main.tf`에 `azurerm_role_assignment` 추가 → `principal_id` = `local.vm_principal_id`, `scope` = remote_state 출력 → plan/apply.  
2. **신규 그룹 모듈**: 기존 `admin-group` 등 **폴더 복사** → 복사본 `variables.tf`에서 역할명 기본값 → 루트에 `module` + `variables.tf` + `terraform.tfvars`에 Object ID·scope·멤버만 추가.  
3. **리소스별 IAM만**: `iam_role_assignments`에 항목 추가(의미는 `terraform.tfvars.example` 주석 참고).

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트에서 시작한다고 가정합니다. **선행:** compute, network, storage, ai-services, apim apply 완료.

**1단계: 변수 파일 복사**
```bash
cd azure/dev/07.rbac
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `hub_subscription_id`, `spoke_subscription_id`, `backend_*`  
- `enable_monitoring_vm_roles`, `enable_key_vault_roles`  
- (선택) `admin_group_*`, `developer_group_*`, `ai_developer_group_*` (Azure AD 그룹 Object ID, scope, 역할, 멤버 목록)

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
cd azure/dev/07.rbac
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, enable_monitoring_vm_roles, enable_key_vault_roles, (선택) 관리자/AI 개발자 그룹 ID
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** compute, network, storage, ai-services (대상 리소스 및 compute의 Identity 확보).  
- **다음 스택:** connectivity.  
- principal_id는 **compute** 스택 output을 remote_state로 읽습니다.

### 권한 부여가 이루어지는 방식 — RBAC가 다른 스택 리소스를 아는 방법

**역할 할당(권한 부여)을 생성하는 스택은 RBAC 하나뿐입니다.**  
compute·network·storage·ai-services는 각자 자신의 리소스(VM, VNet, Key Vault 등)만 관리하며, **역할 할당 리소스는 만들지 않습니다.**

RBAC 스택의 state와 compute/network/storage/ai_services 스택의 state는 **서로 다릅니다.**  
RBAC가 “다른 스택에서 만든 리소스”를 아는 방법은, **해당 스택의 state를 공유하는 것이 아니라**, 그 스택의 **state 파일에 적힌 output 값만 읽는 것**입니다.

- RBAC는 `data "terraform_remote_state" "compute"` / `"network"` / `"storage"` / `"ai_services"` / `"apim"` 로 **각 스택의 state 파일**을 **읽기 전용**으로 조회합니다. (같은 backend 저장소, 키만 `azure/dev/<스택명>/terraform.tfstate` 로 다름.)
- 각 스택은 `output`으로 필요한 식별자(예: `monitoring_vm_identity_principal_id`, `key_vault_id`, `hub_resource_group_id`)를 state에 기록합니다.
- RBAC는 `data.terraform_remote_state.compute.outputs.xxx` 처럼 **그 output 값만** 가져와서, 자신이 만드는 `azurerm_role_assignment`의 `principal_id`·`scope` 등에 넣습니다.

따라서 **다른 스택이 output으로 내보내지 않은 값은 RBAC가 알 수 없습니다.**  
compute뿐 아니라 **network, storage, ai_services, apim**도 동일한 방식입니다. 권한을 받는 쪽(principal)은 compute output 또는 변수로, 권한을 부여할 대상(scope)은 network/storage/ai_services/apim output으로만 참조합니다. 모든 리소스가 이 **remote_state output** 방식으로만 RBAC에 전달됩니다.

### 루트와 하위 모듈의 변수 역할 (변수값은 어디서 지정하나)

RBAC **하위 디렉터리**(admin-group, developer-group, ai-developer-group, *-users)는 **전부 모듈**입니다. plan/apply는 **rbac 루트**에서만 실행하며, 하위에서는 실행하지 않습니다.

| 구분 | 설명 |
|------|------|
| **역할 이름(리소스 정보)** | 각 **그룹 모듈 폴더**의 `variables.tf` **기본값**에서 관리. 예: admin-group의 `role_definition_name` default = "Contributor", ai-developer-group의 `spoke_rg_role_definition_name` default = "Reader". 루트에서는 전달하지 않음. |
| **그룹/scope/멤버(컨텍스트)** | **rbac 루트**의 `terraform.tfvars`(또는 `-var` / `-var-file`)에서 지정. `admin_group_object_id`, `admin_group_scope_id`, `admin_group_member_object_ids` 등. |
| **main.tf의 역할** | 루트 `main.tf`는 **루트 변수**(그룹 ID, scope_id, member_object_ids)만 하위 모듈 인자로 넘김. 역할 이름은 하위 폴더 기본값 사용. |

**흐름 요약:** 그룹/scope/멤버 → 루트 `terraform.tfvars` → 루트 `main.tf` → 하위 모듈. **역할 이름**을 바꿀 때는 **해당 그룹 폴더의 variables.tf** 기본값을 수정. **scope·멤버 목록**을 바꿀 때는 **rbac 루트의 terraform.tfvars** 수정 후 plan/apply.

| 구분 | RBAC가 참조하는 스택 | 용도 (output 예시) |
|------|----------------------|---------------------|
| **권한 받는 쪽 (principal)** | compute | `monitoring_vm_identity_principal_id` (Monitoring VM Identity) |
| **권한 부여 대상 (scope)** | storage | `key_vault_id`, `monitoring_storage_account_ids` |
| | network | `hub_resource_group_id`, `spoke_resource_group_id` |
| | ai_services | `openai_id`, `key_vault_id`, `storage_account_id` |
| | apim | `apim_id` |

### 시나리오 1: 관리자 그룹 / Developer 그룹 / AI 개발자 그룹 ID 설정 방법 (A-6)

- **그룹 생성:** Azure 포털 → Microsoft Entra ID(또는 Azure AD) → **그룹** → 새 그룹 생성. (이름 예: `a-tenant-admins`, `developers`, `ai-developers`.)
- **Object ID 확인:** 해당 그룹 → **개요**에서 **개체 ID** 복사.
- **terraform.tfvars에 설정 (실제 값은 모두 루트 tfvars에서 지정):**
  - **관리자 그룹:** `admin_group_object_id`, `admin_group_scope_id`, `admin_group_member_object_ids`. 역할 이름은 `admin-group/variables.tf` 기본값(Contributor)에서 관리.
  - **Developer 그룹:** `developer_group_object_id`, `developer_group_scope_id`, `developer_group_role_definition_name`(선택, 기본 Reader), `developer_group_member_object_ids`.
  - **AI 개발자 그룹:** `ai_developer_group_object_id`, `ai_developer_group_member_object_ids`. (Spoke RG + OpenAI 역할은 모듈에서 자동 부여.)
- **멤버십 관리:** 각 그룹의 **admin-users** / **developer-users** / **ai-developer-users**는 Terraform으로 멤버십을 관리합니다. 루트 `terraform.tfvars`의 `*_member_object_ids` 목록을 수정한 뒤 `terraform apply`로 등록·변경·삭제합니다. 목록에서 제거 후 apply 시 해당 멤버가 그룹에서 제거됩니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/07.rbac
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수, enable_monitoring_vm_roles, enable_key_vault_roles, (선택) admin_group_object_id, ai_developer_group_object_id, resource_iam_assignments 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

RBAC 스택은 **리소스를 생성하지 않고**, 다른 스택이 만든 리소스에 **역할 할당**만 부여합니다. 따라서 apply 시 "무엇을 어디에 생성하는가"가 아니라 "어떤 principal에 어떤 scope에 어떤 역할을 부여하는가"가 핵심입니다.

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/07.rbac/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | enable_monitoring_vm_roles, admin_group_object_id, resource_iam_assignments 등 |
| 3. **remote_state: compute** | Monitoring VM의 **principal_id**(Managed Identity) 획득. 역할 할당의 "대상 주체". | `data.terraform_remote_state.compute.outputs.monitoring_vm_identity_principal_id`. **선행:** compute apply 완료. |
| 4. **remote_state: network** | Hub/Spoke RG ID 획득. 역할 부여 **scope**(범위)로 사용. | `hub_resource_group_id`, `spoke_resource_group_id` |
| 5. **remote_state: storage** | Key Vault ID, Storage 계정 ID 등. Key Vault/Storage 역할 부여 scope. | `key_vault_id`, `monitoring_storage_account_ids` |
| 6. **remote_state: ai_services** | OpenAI, AI Key Vault, Storage ID. AI 리소스 역할 부여 scope. | `openai_id`, `key_vault_id`, `storage_account_id` |
| 7. **remote_state: apim** | APIM ID. APIM 역할 부여 scope. | `apim_id` |
| 8. locals 계산 | `scope_refs` 등. 변수 `resource_iam_assignments`의 scope_ref 키를 실제 리소스 ID로 매핑. | 위 remote_state outputs → scope_refs["storage_key_vault_id"] 등 |
| 9. 역할 할당 생성 | `azurerm_role_assignment` 리소스. principal_id = compute output, scope = storage/network/ai_services/apim output. 구독은 **역할을 부여하는 리소스가 있는 구독**(Hub 또는 Spoke). | `local.vm_principal_id`, `data.terraform_remote_state.storage.outputs.key_vault_id` 등 |
| 10. 그룹 모듈 (옵션) | admin-group, ai-developer-group 모듈. Azure AD 그룹에 구독/RG 역할 부여, 멤버십 등록. **역할 이름**은 각 폴더 variables.tf 기본값, **그룹/scope/멤버**는 루트 tfvars. | `var.admin_group_*`, `var.ai_developer_group_*` 등 + 폴더 기본값(role_definition_name 등) |

**정리:** principal_id는 **Compute 스택 output**, scope(리소스 ID)는 **Network/Storage/AI Services/APIM 스택 output**에서만 가져옵니다. RBAC는 **어떤 리소스도 만들지 않고**, 위 output들을 조합해 `azurerm_role_assignment`만 생성합니다.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** (hub/spoke 구독) 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state"** … → **locals** 계산 → **azurerm_role_assignment** 및 **module "admin_group"**, **module "developer_group"**, **module "ai_developer_group"** 호출(각 모듈에 var.xxx 전달). 6. **./admin-group/** 등 — 그룹 역할·멤버십. 7. **outputs.tf**

**의존성:** main.tf → remote_state(compute, network, storage, ai_services, apim) → 각 스택 output으로 principal_id·scope 결정 → 역할 할당 생성. **compute, network, storage(필요 시), ai_services(필요 시), apim(필요 시) 선배포 필수.**

---

## 3. 추가 가이드 (역할 할당 추가 / 신규 그룹 추가)

**공통 절차**  
- **VM 역할 추가:** 루트 `main.tf`에 `azurerm_role_assignment` 블록 추가 → 변수·tfvars 반영 → 루트에서 plan → apply.  
- **신규 그룹(서비스 관리자 그룹 등) 추가:** 아래 “신규 그룹 폴더 추가” 절차 따름.

### 신규 그룹 폴더 추가 (예: 서비스 관리자 그룹)

1. **기존 그룹 폴더 복사**  
   `admin-group` 또는 `ai-developer-group` 폴더를 복사해 새 이름 생성 (예: `service-admin-group`).  
   **(복사 후 수정 가이드:** `admin-group/main.tf`, `ai-developer-group/main.tf` 상단 주석에 "신규 그룹 추가 시 이 폴더를 통째로 복사한 뒤" 루트에서 수정할 항목이 정리되어 있음.)  
   복사한 폴더 안 **admin-users** / **ai-developer-users**와 동일한 이름 규칙(예: `service-admin-users`)으로 멤버십 관리용 하위 모듈을 유지합니다.

2. **복사한 폴더에서만 수정**  
   새 폴더의 **variables.tf**에서 **역할 이름**(`role_definition_name` 등) 등 해당 그룹용 기본값만 수정. scope·멤버는 루트에서 전달하므로 폴더에서 바꿀 필요 없음.

3. **루트 main.tf에 module 블록 추가**  
   `module "service_admin_group" { source = "./service-admin-group"; providers = { azurerm = azurerm.hub; azuread = azuread }; group_object_id = var.service_admin_group_object_id; scope_id = var.service_admin_group_scope_id; member_object_ids = var.service_admin_group_member_object_ids; }` 형태로 추가 (역할 이름은 전달하지 않음, 폴더 기본값 사용. count는 변수로 활성화 여부 제어).

4. **루트 variables.tf에 변수 추가**  
   `service_admin_group_object_id`, `service_admin_group_scope_id`, `service_admin_group_member_object_ids` 등 **그룹/scope/멤버만** 정의. 역할 이름 변수는 추가하지 않음.

5. **terraform.tfvars에 값 설정**  
   위 변수(그룹 Object ID, scope ID, 멤버 목록)에 맞게 값 입력.

6. **배포**  
   **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

### 리소스별 IAM 역할 할당 추가/변경/삭제 (시나리오 2)

- **추가:** `terraform.tfvars`의 `iam_role_assignments` 목록에 항목 추가. `principal_id`(사용자·그룹·Managed Identity Object ID), `role_definition_name`, `scope_ref`(또는 `scope`에 ARM ID), `use_spoke_provider`(Spoke 구독이면 true) 지정 후 **이 스택 루트에서** `terraform plan` → `apply`.
- **변경:** 동일 principal/scope/role 조합을 수정하려면 기존 항목을 삭제하고 새 항목으로 추가한 뒤 apply (역할 할당이 replace될 수 있음).
- **삭제:** `iam_role_assignments` 목록에서 해당 항목을 제거한 뒤 `terraform plan` → `apply`로 역할 할당 제거.
- **scope_ref** 사용 가능 값: `storage_key_vault_id`, `ai_services_openai_id`, `ai_services_key_vault_id`, `ai_services_storage_id`, `network_hub_rg_id`, `network_spoke_rg_id`, `apim_id`. 그 외 리소스는 `scope`에 ARM 리소스 ID 전체 입력.

### APIM(Spoke 구독)에 권한 부여하는 방법

APIM은 **Spoke 구독**에 있으므로 `use_spoke_provider = true`로 설정합니다.

1. **terraform.tfvars**의 `iam_role_assignments` 목록에 항목 추가.
2. **principal_id**에 권한을 부여할 사용자·그룹·Managed Identity의 Azure AD Object ID 입력.
3. **role_definition_name**에 부여할 역할 이름 입력 (예: `API Management Service Contributor Role`, `Reader`).
4. **scope_ref**에 `"apim_id"` 지정.
5. **use_spoke_provider**에 `true` 지정 (APIM이 Spoke 구독에 있음).
6. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

예시는 `terraform.tfvars.example`의 시나리오 2 주석을 참고하세요.

### VM에 역할 1개 더 부여 (Monitoring VM용)

1. 루트 `main.tf`에 `azurerm_role_assignment` 리소스 블록 추가.  
2. `scope`는 `data.terraform_remote_state.*.outputs.*`로 참조, `principal_id`는 `local.vm_principal_id` 사용.  
3. 루트에서 plan → apply.

---

## 4. 변경 가이드 (기존 역할 수정)

- **그룹 모듈의 역할 이름 변경**  
  **해당 그룹 폴더의 variables.tf** 기본값(`role_definition_name`, `spoke_rg_role_definition_name` 등) 수정 후 루트에서 plan → apply.

- **그룹 모듈의 Scope·멤버 변경**  
  루트 `variables.tf`·`terraform.tfvars`의 해당 그룹용 변수(`admin_group_scope_id`, `admin_group_member_object_ids` 등) 수정 후 루트에서 plan → apply.

- **리소스별 IAM(시나리오 2) 변경**  
  `terraform.tfvars`의 `iam_role_assignments`에서 해당 항목의 `role_definition_name`·`scope_ref`·`use_spoke_provider` 등 수정 후 plan → apply.

- **VM 역할 변경**  
  루트 `main.tf`의 해당 `azurerm_role_assignment`에서 `role_definition_name` 또는 `scope` 수정 후 plan → apply.

- 역할 할당은 보통 **replace**가 되므로 plan에서 destroy + create 1건으로 나올 수 있습니다.

---

## 5. 삭제 가이드 (역할 제거)

- **그룹 모듈(폴더) 제거**  
  1. 루트 `main.tf`에서 해당 그룹의 `module "xxx" { ... }` 블록 전체 삭제(또는 count=0 등으로 비활성화).  
  2. `variables.tf`·`terraform.tfvars`에서 해당 그룹용 변수 제거 또는 주석 처리.  
  3. `terraform plan`으로 destroy 대상 확인 후 `apply`로 적용.  
  4. (선택) 해당 그룹 폴더(예: `service-admin-group`) 삭제.

- **리소스별 IAM(시나리오 2) 역할 제거**  
  `terraform.tfvars`의 `iam_role_assignments` 목록에서 해당 항목을 삭제한 뒤 plan → apply.

- **VM 역할 할당만 제거**  
  1. 제거할 `azurerm_role_assignment` 블록을 루트 `main.tf`에서 삭제(또는 주석 처리).  
  2. plan으로 destroy 확인 후 apply.

- **Monitoring VM 자체를 삭제한 경우**  
  compute 스택에서 해당 VM을 제거하면 `local.vm_principal_id`가 null이 되어 VM 관련 역할 할당이 count 0이 되며, plan에서 destroy만 나옵니다. apply로 정리합니다.

---

## 6. 디렉터리 구성

| 디렉터리 | 역할 |
|----------|------|
| **rbac/** (루트) | main.tf, variables.tf, outputs.tf, backend.tf, provider.tf. 여기서만 plan/apply. Monitoring VM 역할 + 그룹 모듈 호출. **실제 변수값은 terraform.tfvars에서 지정.** |
| **admin-group/** | 관리자 그룹 모듈 (구독 또는 RG 범위 역할 부여). 기본값은 모듈 variables.tf, 실제값은 루트 tfvars. |
| **admin-group/admin-users/** | 관리자 그룹 멤버십 등록/변경/삭제 (Terraform, `admin_group_member_object_ids`) |
| **developer-group/** | Developer 그룹 모듈 (기본 Reader). 기본값은 모듈 variables.tf, 실제값은 루트 tfvars. |
| **developer-group/developer-users/** | Developer 그룹 멤버십 등록/변경/삭제 (Terraform, `developer_group_member_object_ids`) |
| **ai-developer-group/** | AI 개발자 그룹 모듈 (Spoke RG + OpenAI 역할 부여). 기본값은 모듈 variables.tf, 실제값은 루트 tfvars. |
| **ai-developer-group/ai-developer-users/** | AI 개발자 그룹 멤버십 등록/변경/삭제 (Terraform, `ai_developer_group_member_object_ids`) |
| **(신규 그룹)** | 위 예시 그룹 폴더 복사 후 루트에 module·변수·tfvars 추가 (그룹명-users 하위 모듈 유지) |

---

## 7. 참고

- 대상 리소스 ID는 **remote_state**로 compute, network, storage, ai_services, apim에서 읽습니다.
- **Monitoring VM** 역할은 **compute** 스택 output의 `principal_id`에 부여됩니다.
- **하위 디렉터리는 모두 모듈**: admin-group, developer-group, ai-developer-group 및 *-users는 **모듈**이며, **기본 변수값**은 각 모듈의 variables.tf에, **실제 변수값**은 **rbac 루트**의 `terraform.tfvars`에서 지정합니다. 루트 `main.tf`는 `var.xxx`를 모듈 인자로 **전달만** 합니다. 자세한 흐름은 위 **「루트와 하위 모듈의 변수 역할」** 절을 참고하세요.
- **시나리오 1** 그룹 기반 권한은 **그룹별 폴더(모듈)**로 관리하며, 각 그룹의 Azure AD Object ID·scope·역할·멤버 목록은 **루트 terraform.tfvars**에 입력합니다. 그룹 **멤버십**은 `*_member_object_ids` 목록 수정 후 `apply`로 등록/변경/삭제합니다.
- **시나리오 2** 리소스별 IAM은 **`iam_role_assignments`** 변수로 관리합니다. Key Vault·Storage·OpenAI·RG 등 리소스에 대한 (principal, 역할, scope) 매핑을 목록으로 정의하고, 추가/변경/삭제 시 해당 목록만 수정한 뒤 루트에서 plan/apply하면 됩니다.
