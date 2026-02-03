# 루트 .tf 파일 — 왜 두 개로만 관리해도 여기는 남나요?

## 요약

- **루트 .tf 파일은 "계속 사용"합니다.**  
  Terraform은 **반드시 루트 설정**이 있어야 `terraform plan` / `apply`를 실행할 수 있습니다.
- **공통 모듈 / IaC 모듈** = 루트가 **불러서 쓰는** 라이브러리입니다.  
  루트를 없애면 모듈만 있어도 실행할 곳이 없습니다.
- **"공통 모듈이나 IaC로 못 빼는가?"**  
  - **파일 자체** (main.tf, variables.tf 등) → **빼는 게 아니라 "루트"로 둡니다.**  
  - **main.tf 안의 인라인 리소스** (Solutions, Action Group, Dashboard, Role Assignment 등) → **IaC 전용 모듈로 뺄 수 있습니다.**  
    뺀 뒤에는 루트 main.tf에는 **모듈 호출 + 꼭 필요한 인라인만** 남깁니다.

---

## 루트 vs IaC 모듈 — 누가 누구에 종속?

**루트 .tf가 IaC 모듈에 종속되는 것이 아닙니다.** 반대입니다.

- **루트** = `terraform apply`의 **진입점(주체)**.  
  루트의 **main.tf**가 **공통 모듈**과 **IaC 모듈**을 **호출**합니다.
- **공통 모듈 / IaC 모듈** = 루트에 **의해 호출되는** 쪽.  
  즉, **모듈들이 루트에 종속**됩니다 (루트가 없으면 호출될 수 없음).

```
terraform apply (실행)
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  루트 (terraform-config 루트 .tf)                         │
│  main.tf, variables.tf, outputs.tf, provider.tf,         │
│  terraform.tf, locals.tf, data.tf                        │
│  → 진입점. 여기서 모듈을 "호출"함.                          │
└─────────────────────────────────────────────────────────┘
       │
       │  호출 (module "hub_vnet" { ... }, module "log_analytics_workspace" { ... } 등)
       ▼
┌──────────────────────┐     ┌──────────────────────┐
│  공통 모듈            │     │  IaC 모듈             │
│  (terraform_modules) │     │  (modules/)           │
│  log-analytics-      │     │  hub-vnet, spoke-vnet,│
│  workspace, vnet-    │     │  monitoring-storage,  │
│  peering, virtual-   │     │  shared-services …   │
│  machine …           │     │                      │
└──────────────────────┘     └──────────────────────┘
```

→ 따라서 **루트 .tf는 "IaC 모듈에 종속"이 아니라, "IaC/공통 모듈을 호출하는 쪽"**입니다.

---

## Terraform 배포 시 흐름

1. **루트**에서 `terraform plan` / `apply` 실행.
2. **루트 main.tf**가 **공통 모듈**과 **IaC 모듈**을 호출할 때,  
   **variables.tf / locals.tf**에 정의된 값(리소스 그룹명, VNet명, 주소 공간, 태그 등)을 **인자로 넘깁니다.**
3. 각 모듈은 그 인자에 맞춰 **Azure 리소스**를 생성/갱신합니다.  
   → 루트에 명시된 **리소스 그룹명, VNet명 등**에 맞춰 **특정 Azure 인프라(구독·리전)** 에 **Azure 서비스**가 배포됩니다.
4. **provider.tf**의 구독 ID(Hub/Spoke)와 **terraform.tf**의 Backend 설정에 따라, **어느 구독·어디에 상태를 저장할지**가 정해집니다.

정리하면, **"IaC 루트(루트 .tf)가 공통 모듈을 호출하고, 루트에 명시된 리소스 그룹명·VNet명 등에 맞춰 특정 Azure 인프라에 Azure 서비스를 배포한다"**가 맞습니다.

---

## 루트 .tf 파일은 보통 어떻게 관리하나?

루트 .tf는 **배포의 진입점**이므로, 아래처럼 관리하는 것이 일반적입니다.

### 1. 버전 관리 (Git)

- **루트 .tf 전체**를 Git 저장소(예: terraform-iac 레포)에 둡니다.
- **main.tf, variables.tf, outputs.tf, provider.tf, terraform.tf, locals.tf, data.tf** 는 모두 커밋 대상.
- 변경 이력·리뷰·롤백을 위해 **브랜치 전략**(main + feature 브랜치 등)을 정합니다.

### 2. 환경별 값 분리 — tfvars

- **variables.tf** 에는 변수 **정의**만 두고, **실제 값**은 **tfvars** 로 분리합니다.
- **terraform.tfvars** 는 예시만 커밋하고(terraform.tfvars.example), **실제 값이 들어간 terraform.tfvars** 는 **.gitignore** 에 넣어 Git에 올리지 않습니다.
- 환경별로 파일을 나누면:
  - `dev.tfvars`, `staging.tfvars`, `prod.tfvars` 등
  - 실행 시: `terraform plan -var-file=prod.tfvars`
- 비밀(구독 ID, 비밀번호 등)은 tfvars 대신 **환경 변수**(`TF_VAR_xxx`) 또는 **Azure Key Vault 등**에서 주입하는 방식을 많이 씁니다.

### 3. State(상태) 관리 — Backend (S3/스토리지 버전 관리)

- **terraform.tf** 에 **backend "azurerm"** 또는 **backend "s3"** 등을 설정해, **state 파일**을 **원격 스토리지**에 저장합니다.
- 팀원이 같은 state를 보도록 하고, **state 잠금**으로 동시 apply 충돌을 막습니다.
- 환경/구독마다 **backend key** 를 다르게 두면(예: `key = "prod/terraform.tfstate"`) 환경별 state 분리가 됩니다.
- **S3(또는 Azure Blob) 버킷에 버전 관리(Versioning)를 켜 두면** — state 파일을 덮어써도 이전 버전이 남아, 실수로 state가 망가졌을 때 복구하기 좋습니다.  
  → 즉, **S3 등 스토리지에 “버전 관리 모드”로 관리하는 것은 State 쪽에 권장**됩니다.

**루트 .tf “코드”를 S3에 버전 관리로 올리는 것은?**

- **.tf 파일(코드)의 버전 관리**는 보통 **Git**(GitHub, GitLab 등)으로 합니다.  
  Git은 변경 이력, diff, 코드 리뷰(PR), 브랜치, 롤백을 지원하므로 코드 관리에 적합합니다.
- **루트 .tf를 S3에 업로드해 버전 관리**하는 방식은:
  - **주된 코드 버전 관리 수단으로 쓰기에는 비권장**입니다. S3에는 diff/리뷰/브랜치가 없고, Terraform/팀 워크플로와 잘 맞지 않습니다.
  - **백업·아카이브** 목적으로, Git 레포를 주기적으로 S3에 복사해 두는 것은 가능합니다. 다만 **일상적인 버전 관리와 배포 기준은 Git**으로 두는 것이 HashiCorp 권장 및 업계 관례에 맞습니다.

| 대상 | 권장 저장소 | 버전 관리 |
|------|-------------|-----------|
| **State** | S3 / Azure Blob / GCS (backend) | ✅ 버킷 버전 관리 권장 (state 복구용) |
| **루트 .tf 코드** | **Git** (GitHub 등) | ✅ Git으로 버전 관리. S3는 백업/아카이브용으로만 선택적 사용 |

### 4. 환경별 루트를 나누는 방법 (선택)

- **한 루트에 tfvars만 바꿔 쓰는 방식**  
  - 루트 .tf는 한 세트. `-var-file=dev.tfvars` / `prod.tfvars` 로 구분.
- **환경마다 디렉터리를 두는 방식**  
  - 예: `environments/dev/`, `environments/prod/`  
  - 각 디렉터리에 **자기 환경용** main.tf, variables.tf, provider.tf, terraform.tf, tfvars 를 두고, 공통 모듈은 `source = "../../modules/..."` 또는 git으로 참조.
- **Terraform Workspace**  
  - `terraform workspace select prod` 로 workspace만 바꾸고, 같은 루트 .tf에서 변수/backend key를 workspace별로 다르게 쓰는 방식. (상대적으로 덜 쓰이는 편.)

### 5. 누가 무엇을 수정하는지

- **main.tf**  
  - 모듈 추가/제거, 인라인 리소스 변경 → **인프라 변경**이므로 리뷰 후 적용.
- **variables.tf / outputs.tf**  
  - 새 변수/출력 추가·정의 변경 → 역시 리뷰.
- **provider.tf**  
  - 구독 ID, alias 등 → **환경/계정 정보**이므로 변경 시 신중히.
- **terraform.tf**  
  - Backend, provider 버전 → **전체 실행 환경**에 영향.
- **locals.tf / data.tf**  
  - 이름 규칙, data 소스 → 필요 시 수정하되, 네이밍/정책과 맞추어 관리.

### 6. 정리

| 항목 | 보통 하는 관리 |
|------|----------------|
| **코드** | Git 저장소에 루트 .tf 전부 커밋, 브랜치/PR 사용 |
| **환경별 값** | tfvars(또는 env별 디렉터리), 실제 tfvars는 .gitignore |
| **비밀** | tfvars 대신 환경 변수 / Key Vault 등 |
| **State** | terraform.tf 에 remote backend 설정, 환경별 key 분리 |
| **변경** | main/variables/outputs/provider 변경은 리뷰 후 적용 |

**HashiCorp 공식 권장 방법**으로 맞추고 싶다면 → **[HASHICORP_RECOMMENDED_PRACTICES.md](./HASHICORP_RECOMMENDED_PRACTICES.md)** 참고 (표준 모듈 구조, 원격 State, 비밀 관리, 환경 분리, 스타일/검증 등).

→ 루트 .tf는 **“한 레포(또는 환경별 디렉터리)에서 버전 관리 + tfvars로 환경 분리 + backend로 state 공유”** 하는 방식으로 관리하면 됩니다.

---

## 루트에 꼭 있어야 하는 파일 (옮기면 안 됨)

| 파일 | 역할 | 공통/IaC로 옮기기 |
|------|------|-------------------|
| **main.tf** | 모듈 호출 + 루트 리소스. `terraform apply`의 진입점. | **안 옮김.** 대신 *안의 리소스*를 IaC 모듈로 뺄 수 있음. |
| **variables.tf** | 루트 입력 (tfvars와 연결). | **안 옮김.** 환경별 값은 루트에서만 받음. |
| **outputs.tf** | 루트 출력 (배포 결과 노출). | **안 옮김.** |
| **provider.tf** | Azure Provider, Hub/Spoke 구독, alias. | **안 옮김.** Terraform 규약상 루트에 둠. |
| **terraform.tf** | Backend, required_providers, 버전. | **안 옮김.** |

→ 위 파일들은 **"공통 모듈"이나 "IaC 모듈"로 옮기는 대상이 아니라**,  
  **공통 모듈 / IaC 모듈을 "호출하는 쪽"**입니다.

---

## 루트에 두되, 내용만 정리 가능한 파일

| 파일 | 역할 | 정리 방법 |
|------|------|-----------|
| **locals.tf** | Hub/Spoke 이름 등 계산 값. 여러 모듈에 넘기는 값. | 그대로 루트에 두는 게 일반적. (모듈에 변수로 넘기기 위한 계산) |
| **data.tf** | data 소스 (예: azurerm_client_config). | 지금처럼 루트에 두거나, 필요 시 해당 모듈 안에 둘 수 있음. |

---

## main.tf 안에서 IaC 모듈로 뺄 수 있는 것

지금 main.tf에는 **모듈 호출** 외에 아래 인라인 리소스가 있습니다.

| 인라인 리소스 | 설명 | 빼는 방법 |
|---------------|------|-----------|
| Log Analytics Solutions (ContainerInsights, SecurityInsights) | Workspace 위에 붙는 솔루션 2개 | **적용됨.** `modules/dev/hub/shared-services` 로 뺐고, main.tf에서는 `module "shared_services"` 한 번만 호출. |
| Action Group, Dashboard | 모니터링 알림/대시보드 | 위와 동일 모듈에 포함됨. |
| Role Assignment (VM → Storage/KV/Spoke 등) | VM Identity 권한 부여 여러 개 | **선택.** 루트에 두어도 됨 (모듈 간 연결이 명확). 원하면 `modules/dev/hub/role-assignments` 로 묶을 수 있음. |

→ Shared Services는 **modules/dev/hub/shared-services** 로 뺐으므로 main.tf에는 **module 블록 + Role Assignment 인라인**만 남음.  
  **공통 모듈(terraform_modules)** 에는 넣지 않음. (환경당 1세트·조합에 가깝기 때문.)

---

## 정리

- **루트 .tf (main, variables, outputs, provider, terraform, locals, data)**  
  → **계속 사용.**  
  루트가 없으면 apply 자체를 할 수 없고, "공통/IaC로 빼는" 대상이 아님.
- **main.tf *안의* 인라인 리소스**  
  → **IaC 전용 모듈**로 빼면 main.tf가 얇아지고, **공통 모듈 + IaC 모듈 두 개로만 관리**하는 구조와 잘 맞습니다.

원하면 **Shared Services(Solutions/AG/Dashboard)** 와 **Role Assignments** 를 각각 IaC 모듈로 만들어서 main.tf를 정리할 수 있습니다.
