# Shared Services

shared-services 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개, 하위 디렉터리(log-analytics-workspace, shared-services)는 **모듈**로만 호출합니다.

**변수 관리 방식:**  
- **루트**: 구독 ID, backend, location, tags, **remote_state**로 얻는 컨텍스트(Hub RG 이름)만 전달.  
- **log-analytics-workspace 폴더**: Workspace 이름 접미사(`name_suffix`), `retention_in_days` 등 **리소스 정보**는 **log-analytics-workspace/variables.tf 기본값**에서 관리.  
- **shared-services 폴더**: `enable` 등은 **shared-services/variables.tf 기본값**에서 관리.  
→ 신규 Log Analytics Workspace 추가 시 **log-analytics-workspace 폴더 복사** → **복사한 폴더 variables.tf만 수정** → 루트 `main.tf`에 module 블록만 추가. 루트에 인스턴스별 변수 추가하지 않음.

---

## 파일·디렉터리 역할 및 배포 시 수정 위치

### 스택 루트 파일

| 파일 | 역할 | 주로 수정하는 내용 |
|------|------|-------------------|
| `main.tf` | remote_state(network), `log_analytics_workspace`, `shared_services` 모듈 | 모듈 추가·인자 연결 |
| `variables.tf` | 루트 변수 | `project_name`, `location`, tags, backend 관련 등 공통값 |
| `terraform.tfvars` | 배포 값 | `hub_subscription_id`, `backend_*` |
| `backend.tf` / `backend.hcl` | 원격 state | Bootstrap 연동 |
| `provider.tf` | Hub 구독 | 고정에 가까움 |
| `outputs.tf` | Log Analytics ID·이름 등 | apim·ai-services가 참조 |

### 하위 디렉터리

| 디렉터리 | 역할 | 신규/변경 시 |
|----------|------|----------------|
| `log-analytics-workspace/` | LAW (AVM 래퍼) | **폴더 복사 후** `variables.tf`의 `name_suffix`, `retention_in_days`(로그 보존 일수) 등 |
| `shared-services/` | Solutions, Action Group, Dashboard 등 | **폴더 `variables.tf`**의 `enable` 플래그들로 기능 단위 켜기/끄기 |

### 신규 리소스 생성 시 변수(의미)

| 작업 | 수정 위치 | 의미 |
|------|-----------|------|
| **LAW 인스턴스 추가** | `log-analytics-workspace-xx/variables.tf` | `name_suffix`: 이름 구분. `retention_in_days`: 보존 기간(일) |
| **Shared Services 구성** | `shared-services/variables.tf` | 각 `enable_*`: 대시보드·솔루션·액션 그룹 등을 생성할지 여부 |
| **RG 위치** | (자동) network state | LAW가 생성될 Hub RG 이름은 **network 출력**에서만 전달 |

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트(`terraform-iac/`)에서 시작한다고 가정합니다.

**1단계: 스택 디렉터리로 이동 후 변수 파일 복사**
```bash
cd azure/dev/03.shared-services
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `hub_subscription_id`, `backend_*` → 구독 ID 및 Bootstrap과 동일  
- Log Analytics 보존 일수·Shared Services 활성화는 **log-analytics-workspace**, **shared-services** 폴더의 `variables.tf` 기본값에서 관리 (필요 시 해당 폴더만 수정)

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
cd azure/dev/03.shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수 등 (보존 일수·enable은 각 하위 폴더 variables.tf에서 관리)
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network.  
- **다음 스택:** apim, ai-services 등이 이 스택의 Log Analytics output을 참조합니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/03.shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/03.shared-services/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, backend_* 등. 보존 일수·enable은 각 하위 폴더 기본값. |
| 3. **remote_state: network** | Hub RG 이름 획득. Log Analytics·Solutions 등이 생성될 리소스 그룹. | `data.terraform_remote_state.network.outputs.hub_resource_group_name`. **선행:** network apply 완료. |
| 4. 구독 결정 | Log Analytics·Solutions 등은 **Hub 구독**에 생성. | `provider.tf`: `var.hub_subscription_id` |
| 5. module "log_analytics_workspace" | Log Analytics Workspace 생성. 이름·보존 일수는 **폴더 variables.tf 기본값**. RG는 network state에서 전달. | `data.terraform_remote_state.network.outputs.hub_resource_group_name`, `log-analytics-workspace/variables.tf` 기본값(name_suffix, retention_in_days) |
| 6. module "shared_services" | Solutions, Action Group, Dashboard 등(enable 시). enable은 **폴더 variables.tf 기본값**. | `module.log_analytics_workspace.id`, `module.log_analytics_workspace.name`, `shared-services/variables.tf` 기본값(enable) |
| 7. Output 기록 | `log_analytics_workspace_id` 등. apim·ai-services가 참조. | `outputs.tf` |

**정리:** 리소스 그룹 이름은 **Network 스택 output**에서만 가져옴. 이 스택은 선행 스택이 **network** 하나뿐입니다.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state" "network"** 실행 → **locals** → **module "log_analytics_workspace"**, **module "shared_services"** 호출. 6. **./log-analytics-workspace/** 7. **./shared-services/** 8. **outputs.tf**

**의존성:** main.tf → remote_state(network) → network output(hub_resource_group_name) 사용 → 하위 모듈 참조. **network 선배포 필수.**

---

## 3. 추가 가이드 (신규 리소스 추가)

**공통 절차 (신규 인스턴스 추가 시)**  
(1) 해당 폴더 복사 → (2) **복사한 폴더의 variables.tf** 기본값만 수정 → (3) 루트 `main.tf`에 module 블록만 추가 → (4) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.  
(루트 `variables.tf`·`terraform.tfvars`에 인스턴스별 변수 추가하지 않음.)

- **Log Analytics Workspace 추가**  
  1. `log-analytics-workspace` 디렉터리를 통째로 복사한 뒤 폴더명 변경 (예: `log-analytics-workspace-02`).  
  2. **복사한 폴더** `log-analytics-workspace-02/variables.tf`에서 `name_suffix`, `retention_in_days` 등 **해당 인스턴스용 값만 수정**.  
  3. 루트 `main.tf`에 `module "log_analytics_workspace_02" { source = "./log-analytics-workspace-02"; name_prefix = local.name_prefix; location = var.location; resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name; tags = var.tags; }` 블록만 추가.  
  4. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Solutions / Action Group / Dashboard 추가**  
  `shared-services` 모듈 또는 공통 모듈에 옵션이 있으면 **shared-services 폴더 variables.tf** 기본값 또는 루트 변수에 추가 후 **이 스택 루트에서** plan → apply.  
  없으면 terraform-modules 레포 반영 후 `init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **보존 기간·Workspace 이름 접미사·Shared Services 활성화**  
  **log-analytics-workspace/variables.tf**, **shared-services/variables.tf**의 기본값(`retention_in_days`, `name_suffix`, `enable`)을 수정한 뒤 루트에서 `terraform plan -var-file=terraform.tfvars` → `apply`.

- **remote_state로 전달되는 값(RG 이름 등) 변경**  
  루트 `main.tf`의 module 블록 인자 또는 선행 스택(network) 출력 변경 후 plan → apply.

---

## 5. 삭제 가이드 (리소스 제거)

- **Log Analytics 또는 Shared Services 인스턴스 제거**  
  1. 루트 `main.tf`에서 해당 `module "xxx" { ... }` 블록 삭제.  
  2. 관련 변수·output 제거.  
  3. `terraform plan` → `apply`로 destroy 적용.

- **state에서만 제거**  
  `terraform state rm 'module.xxx'` 사용.

---

## 6. 하위 모듈

| 디렉터리 | 역할 |
|----------|------|
| **log-analytics-workspace/** | Log Analytics Workspace (AVM 래핑). 리소스 정보(name_suffix, retention_in_days)는 **이 폴더 variables.tf 기본값**에서 관리. 루트는 name_prefix, location, resource_group_name, tags 만 전달. |
| **shared-services/** | Solutions, Action Group, Dashboard (Git shared-services 래핑). enable 등은 **이 폴더 variables.tf 기본값**에서 관리. |
