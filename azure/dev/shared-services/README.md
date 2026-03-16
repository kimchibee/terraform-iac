# Shared Services

shared-services 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개, 하위 디렉터리(log-analytics-workspace, shared-services)는 **모듈**로만 호출합니다.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트(`terraform-iac/`)에서 시작한다고 가정합니다.

**1단계: 스택 디렉터리로 이동 후 변수 파일 복사**
```bash
cd azure/dev/shared-services
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `hub_subscription_id`, `backend_*` → 구독 ID 및 Bootstrap과 동일  
- `log_analytics_retention_days`, `enable_shared_services` → 필요 시 수정

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
cd azure/dev/shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, log_analytics_retention_days, enable_shared_services 등
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
cd azure/dev/shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수, log_analytics_retention_days, enable_shared_services 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 키 `azure/dev/shared-services/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `terraform.tfvars` → `variables.tf`. | project_name, log_analytics_retention_days, enable_shared_services, backend_* 등 |
| 3. **remote_state: network** | Hub RG 이름 획득. Log Analytics·Solutions 등이 생성될 리소스 그룹. | `data.terraform_remote_state.network.outputs.hub_resource_group_name`. **선행:** network apply 완료. |
| 4. 구독 결정 | Log Analytics·Solutions 등은 **Hub 구독**에 생성. | `provider.tf`: `var.hub_subscription_id` |
| 5. module "log_analytics_workspace" | Log Analytics Workspace 생성. RG 이름은 network state에서 전달. | `data.terraform_remote_state.network.outputs.hub_resource_group_name`, `var.log_analytics_retention_days` |
| 6. module "shared_services" | Solutions, Action Group, Dashboard 등(enable 시). Log Analytics ID 전달. | `module.log_analytics_workspace.id`, `module.log_analytics_workspace.name` |
| 7. Output 기록 | `log_analytics_workspace_id` 등. apim·ai-services가 참조. | `outputs.tf` |

**정리:** 리소스 그룹 이름은 **Network 스택 output**에서만 가져옴. 이 스택은 선행 스택이 **network** 하나뿐입니다.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** 2. **provider.tf** 3. **variables.tf** 4. **terraform.tfvars** 5. **main.tf** — **data "terraform_remote_state" "network"** 실행 → **locals** → **module "log_analytics_workspace"**, **module "shared_services"** 호출. 6. **./log-analytics-workspace/** 7. **./shared-services/** 8. **outputs.tf**

**의존성:** main.tf → remote_state(network) → network output(hub_resource_group_name) 사용 → 하위 모듈 참조. **network 선배포 필수.**

---

## 3. 추가 가이드 (신규 리소스 추가)

**공통 절차 (신규 인스턴스 추가 시)**  
(1) 예시 디렉터리 복사 → (2) 필요 시 새 디렉터리 내 기본값 수정 → (3) 루트 `main.tf`에 module 블록 추가 → (4) 루트 `variables.tf`에 변수 추가 → (5) `terraform.tfvars`에 값 설정 → (6) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Log Analytics Workspace 추가**  
  1. `log-analytics-workspace` 디렉터리를 복사해 새 이름 생성 (예: `log-analytics-workspace-02`).  
  2. 루트 `main.tf`에 `module "log_analytics_workspace_02" { source = "./log-analytics-workspace-02"; ... }` 추가.  
  3. 루트 `variables.tf`에 변수 정의.  
  4. `terraform.tfvars`에 값 설정.  
  5. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Solutions / Action Group / Dashboard 추가**  
  디렉터리 복사 없이 **변수만 반영**: `shared-services` 모듈 또는 공통 모듈에 옵션이 있으면 `variables.tf`·`terraform.tfvars`에 추가 후 **이 스택 루트에서** plan → apply.  
  없으면 terraform-modules 레포 반영 후 `init -upgrade` → plan → apply.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **보존 기간·활성화 여부 등**  
  `terraform.tfvars`에서 `log_analytics_retention_days`, `enable_shared_services` 등 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- **모듈 인자 변경**  
  루트 `main.tf`의 module 블록 인자 또는 하위/공통 모듈 수정 후 plan → apply.

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
| **log-analytics-workspace/** | Log Analytics Workspace (AVM 래핑) |
| **shared-services/** | Solutions, Action Group, Dashboard (Git shared-services 래핑) |
