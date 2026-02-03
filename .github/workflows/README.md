# GitHub Actions

**예시용 워크플로입니다.** 실제 사용 시 Repo **Settings → Secrets and variables → Actions** 에서 아래 시크릿을 추가하고, 각 워크플로 파일 상단 주석에 적힌 대로 **무엇을 넣어야 하는지** 확인한 뒤 값을 채워 넣으세요.

---

## Terraform fmt / validate / plan / apply (`terraform-fmt-validate-plan-apply.yml`)

Terraform 실행 순서: **fmt → init → validate → plan → (선택) apply**.  
어느 단계에서든 실패하면 해당 단계 로그와 plan 파일이 artifact로 올라가서 디버깅할 수 있습니다.

### 트리거

- **수동 실행 (workflow_dispatch)**  
  - **run_apply**: true로 두면 plan 뒤에 **apply**까지 실행 (기본: false, plan만)
  - **environment**: dev / prod (선택)
- **푸시**: `main` 브랜치, `.tf` 또는 `modules/**` 변경 시 → **apply 없이** fmt ~ plan 까지만 실행

### 실행 순서

1. **terraform fmt -recursive** — 포맷 적용  
2. **terraform fmt -check -recursive** — 포맷 검사 (미통과 시 실패)
3. **terraform init** — 백엔드·프로바이더 초기화
4. **terraform validate** — 구문·참조 검증
5. **terraform plan -out=tfplan** — 변경 계획 생성
6. **terraform apply -auto-approve tfplan** — 수동 실행 시 `run_apply=true`일 때만

### 실패 시 디버깅

- **Artifact `terraform-logs-<run_id>`**: 각 단계별 로그 (`fmt.log`, `init.log`, `validate.log`, `plan.log`, `apply.log`), `state-list.log`, `plan-show.log`, `tfplan` 파일
- **Artifact `debug-summary-<run_id>`**: 실패 시 생성되는 `DEBUG_SUMMARY.md` (어느 로그를 보면 되는지 안내)
- Run 실패 시 Actions Run 페이지에서 해당 step 로그 + 위 artifact 다운로드로 원인 분석

### 필요한 시크릿 (무엇을 넣어야 하는지)

| 시크릿 | 넣을 값 |
|--------|---------|
| `HUB_SUBSCRIPTION_ID` | Hub 구독 ID (Azure Portal 구독 목록에서 복사, GUID 형식) |
| `SPOKE_SUBSCRIPTION_ID` | Spoke 구독 ID (동일하게 GUID) |
| `ARM_CLIENT_ID` | Azure 서비스 프린시펄(또는 앱 등록)의 **Application (client) ID** |
| `ARM_CLIENT_SECRET` | 해당 서비스 프린시펄의 **Client secret** 값 |
| `ARM_TENANT_ID` | Azure AD **Directory (tenant) ID** |
| `AZURE_CLIENT_ID` | (선택) OIDC 사용 시 앱 등록 Client ID (ARM_CLIENT_ID 와 동일해도 됨) |
| `AZURE_TENANT_ID` | (선택) OIDC용 Tenant ID |

Backend `azurerm` 사용 시 위 ARM_* 로 Storage 접근 가능한 서비스 프린시펄이어야 합니다.

---

## Azure Resource Comparison (`azure-resource-comparison.yml`)

Terraform 코드와 실제 Azure 리소스를 비교하기 위한 워크플로입니다.

### 트리거

- **수동 실행 (workflow_dispatch)**  
  Actions 탭에서 "Azure Resource Comparison" 선택 후 "Run workflow"  
  - **Run terraform plan**: Terraform plan 실행 (구독 ID 시크릿 필요)  
  - **Run az resource list**: Azure 구독 리소스 목록 수집 (Azure 로그인 시크릿 필요)
- **푸시**: `main` 브랜치에 `.tf` 또는 `modules/**` 변경 시 → Terraform init + validate만 실행
- **스케줄**: 매주 월요일 09:00 KST → init + validate

### 시크릿 (무엇을 넣어야 하는지)

| 시크릿 | 넣을 값 |
|--------|---------|
| `HUB_SUBSCRIPTION_ID` | Hub 구독 ID (GUID) — plan / Azure 리스트 시 사용 |
| `SPOKE_SUBSCRIPTION_ID` | Spoke 구독 ID (GUID) |
| `AZURE_CLIENT_ID` | Azure OIDC용 App Registration 의 **Application (client) ID** |
| `AZURE_TENANT_ID` | Azure AD **Directory (tenant) ID** |
| `ARM_CLIENT_ID` | (state list 시) Backend Storage 접근 가능한 서비스 프린시펄 Client ID |
| `ARM_CLIENT_SECRET` | (state list 시) 해당 Client Secret |
| `ARM_TENANT_ID` | (state list 시) Tenant ID |

Azure 리소스 목록 수집 시 Azure App Registration 에 **Federated credential (GitHub OIDC)** 설정이 필요합니다.

### 아티팩트

- **terraform-outputs**: `plan-output.txt`, `state-list.txt` (있을 경우)
- **azure-resource-lists**: `hub-resources.txt`, `spoke-resources.txt` (있을 경우)
- **comparison-report**: `COMPARISON_REPORT.md` (요약)

자세한 비교 방법은 [docs/AZURE_RESOURCE_COMPARISON.md](../docs/AZURE_RESOURCE_COMPARISON.md)를 참고하세요.
