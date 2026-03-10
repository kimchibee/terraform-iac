# Shared-Services 배포 가이드

Log Analytics Workspace, Solutions(Container Insights, Security Insights), Action Group, Portal 대시보드를 관리하는 스택입니다. **선행 스택:** storage. **다음 스택:** apim.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `location`, `tags` | 공통 식별자·리전·태그 | 프로젝트 규칙 (예: `test`, `dev`, `Korea Central`) |
| `hub_subscription_id` | Hub 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `log_analytics_retention_days` | Log Analytics 보존 일수 | 예: `30`. 변수 기본값 있음. |
| `enable_shared_services` | Solutions·Action Group·Dashboard 생성 여부 | 기본 `true`. false면 해당 리소스 미생성. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/shared-services
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

Log Analytics 이름은 locals/모듈에서 `project_name` 등으로 생성. Solutions·Action Group·Dashboard는 모듈 내 네이밍 사용.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| Log Analytics Workspace | LAW | 1 | `module.log_analytics_workspace` (AVM 모듈). 이름은 스택 locals의 `hub_log_analytics_name` (예: `test-x-x-law`) |
| Log Analytics Solution | Container Insights | 1 | 모듈 내 네이밍 (ContainerInsights) |
| Log Analytics Solution | Security Insights | 1 | 모듈 내 네이밍 (SecurityInsights) |
| Action Group | 알림 그룹 | 1 | `module.shared_services.azurerm_monitor_action_group.main` (예: test-action-group) |
| Portal Dashboard | 대시보드 | 1 | `module.shared_services.azurerm_portal_dashboard.main` (예: test-dashboard) |

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: Solution 1개 추가)

1. **공통 모듈(log-analytics-workspace, shared-services)**에 해당 리소스가 있으면: 스택에서 변수/인자만 추가 후 plan/apply.  
2. **모듈에 없는 리소스:** **3.4**에 따라 terraform-modules 레포에 템플릿 추가 후 push → 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply.

### 3.2 기존 리소스 변경 (예: 보존 일수, 태그)

1. `terraform.tfvars` 또는 모듈 인자 수정 후 `terraform plan` → `apply`로 적용합니다.  
2. 모듈 스키마 변경이 필요하면 모듈 레포 수정 후 **3.4** 순서를 따릅니다.

### 3.3 기존 리소스 삭제

1. 제거할 리소스에 해당하는 모듈 인자 또는 리소스 블록을 제거(또는 비활성화)합니다.  
2. `terraform plan`으로 destroy 확인 후 `apply`로 삭제합니다.  
3. state만 제거: `terraform state rm '주소'`.

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

1. terraform-modules 레포에서 해당 모듈 수정 후 커밋·push.  
2. **이 스택(shared-services)에서:**  
   - `terraform init -backend-config=backend.hcl -upgrade`  
   - `terraform plan -var-file=terraform.tfvars`  
   - `terraform apply -var-file=terraform.tfvars`
