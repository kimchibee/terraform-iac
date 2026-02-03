# HashiCorp 권장 방법으로 Terraform 관리하기

HashiCorp 공식 문서를 기준으로, 루트 .tf 및 모듈을 **권장 방식**에 맞추려면 어떻게 하면 되는지 정리했습니다.  
공식 링크는 문서 하단에 모아 두었습니다.

---

## 1. 표준 모듈 구조 (Standard Module Structure)

**출처:** [Standard Module Structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)

- **루트 모듈(Root module)**  
  - 저장소 **루트**에 있는 .tf 파일이 **진입점**.  
  - 반드시 필요.
- **권장 파일명**
  - `main.tf` — 주 진입점(리소스·모듈 호출)
  - `variables.tf` — 입력 변수
  - `outputs.tf` — 출력
- **모듈용**
  - 재사용 모듈은 `modules/` 하위에 두거나, 별도 레포로 분리.
  - 각 모듈에도 `README.md`, 필요 시 `LICENSE` 권장.
- **변수·출력**
  - 모든 variable/output에 **description** 한두 문장 권장.

**현재 프로젝트에 적용:**  
- 루트에 `main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `terraform.tf`, `locals.tf`, `data.tf` 유지.  
- 공통 모듈은 **terraform-modules 레포**에서, IaC 모듈은 이 레포 `modules/` 에서 관리. 각 모듈에 `README.md` 및 변수/출력 description 보강 권장.

---

## 2. 버전 관리 + 코드 리뷰

**출처:** [Recommended practices Part 1](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part1), [Part 3.2](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part3.2)

- **모든 Terraform 코드를 VCS(Git 등)에** 넣기.
- **Pull Request(코드 리뷰)** 후 머지.
- **수동 변경 최소화** — 변경은 코드로 하고, apply는 파이프라인 또는 통제된 절차로.

**적용:**  
- 루트 .tf와 `modules/`(IaC)는 이 레포에, 공통 모듈은 **terraform-modules 레포**에 Git 커밋.  
- main/variables/outputs 변경은 PR로 리뷰 후 적용.

---

## 3. 원격 State + 잠금 (Remote State with Locking)

**출처:** [State Storage and Locking](https://developer.hashicorp.com/terraform/language/state/backends), [Remote State](https://developer.hashicorp.com/terraform/language/state/remote)

- **State는 원격 Backend**에 저장 (로컬 기본값 사용 지양).
- **State locking**으로 동시 apply 충돌 방지.
- 지원 Backend 예: **azurerm**, **s3**, **gcs**, **remote**(HCP Terraform) 등.

**적용:**  
- `terraform.tf`에 `backend "azurerm"` (또는 사용 중인 Backend) 설정.  
- 팀이 같은 state를 쓰고, 잠금이 지원되는 Backend 사용.

```hcl
# terraform.tf 예시
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "terraformstate"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"   # 환경별로 key 분리 가능 (예: prod/terraform.tfstate)
  }
}
```

---

## 4. 비밀/민감 데이터 관리

**출처:** [Sensitive data in configuration](https://developer.hashicorp.com/terraform/language/state/sensitive-data)

- **variable**에 비밀/민감 값이면 `sensitive = true` 지정.
- **실제 비밀 값**은 tfvars 파일에 넣지 말고, **환경 변수**(`TF_VAR_xxx`) 또는 **HCP Terraform / Vault** 등에서 주입.
- **State**에 민감 정보가 들어가지 않도록, 가능하면 **ephemeral** 값 사용(Terraform 1.10+).

**적용:**  
- `variables.tf`에서 비밀 변수에 `sensitive = true` 추가.  
- `terraform.tfvars`는 .gitignore, 실제 값은 CI/로컬에서 `TF_VAR_*` 또는 시크릿 저장소로 전달.

---

## 5. 환경 분리 — Workspace vs 디렉터리

**출처:** [State: Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces), [Workspace Best Practices](https://developer.hashicorp.com/terraform/enterprise/workspaces/best-practices)

- **Workspace**
  - **같은 코드**로 **여러 state**만 나누고 싶을 때 사용.
  - `${terraform.workspace}` 로 이름만 구분.
  - **서로 다른 구독/권한/설정**이 크게 다르면 부적합.
- **환경별로 설정이 크게 다를 때**
  - **환경마다 디렉터리** (`environments/dev/`, `environments/prod/`)를 두고,  
    각 디렉터리에 루트 .tf + 해당 환경용 tfvars/backend key를 두는 방식을 권장.

**적용:**  
- dev/staging/prod가 **같은 코드 + tfvars만 다름** → Workspace 또는 **한 루트 + `-var-file=env.tfvars`**.  
- 구독·리소스 구성이 **환경마다 많이 다름** → **environments/<env>/** 구조 권장.

---

## 6. 코드 스타일 및 검증

**출처:** [Style Guide](https://developer.hashicorp.com/terraform/language/style)

- **`terraform fmt`** — 커밋 전 포맷 통일.
- **`terraform validate`** — 문법/구성 검증.
- **리소스 이름** — 타입 이름 제외, 명사 사용, 단어 구분은 언더스코어(`_`).
- **들여쓰기** — 2칸 스페이스.

**적용:**  
- CI 또는 로컬에서 `terraform fmt -recursive` 및 `terraform validate` 실행.  
- (선택) TFLint 등 린터 사용.

---

## 7. HCP Terraform(Terraform Cloud) 사용 시

**출처:** [Recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices), [Project Best Practices](https://developer.hashicorp.com/terraform/cloud-docs/projects/best-practices)

- **cloud** 블록 사용 시에는 **backend** 블록을 두지 않음 (상호 배타).
- **Workspace** 단위로 환경 분리, **Variable Set**으로 공통 변수/비밀 관리.
- **VCS 연동**으로 PR 시 speculative plan, 머지 시 apply 자동화.
- **Run Tasks**로 정책/보안 검사(예: 비용·보안 스캔) 적용 가능.

**적용:**  
- Terraform Cloud/Enterprise를 쓰면, 루트에는 `cloud` 블록만 두고,  
  환경별 Workspace + Variable Set으로 루트 .tf와 연동.

---

## 8. 체크리스트 — 지금 프로젝트에 적용할 수 있는 것

| 항목 | HashiCorp 권장 | 적용 방법 (terraform-config) |
|------|----------------|------------------------------|
| **루트 구조** | main.tf, variables.tf, outputs.tf 등 루트에 진입점 유지 | ✅ 이미 루트 .tf로 구성됨 |
| **모듈 구조** | modules/ 또는 별도 레포, README·description | ✅ 공통 모듈은 terraform-modules 레포, IaC 모듈은 `modules/`. description 보강 권장 |
| **버전 관리** | 전체 코드 Git, PR 리뷰 | ✅ Git 사용. PR 워크플로우 적용 권장 |
| **원격 State** | backend로 원격 저장 + 잠금 | ⬜ `terraform.tf`에서 backend "azurerm" (또는 사용 Backend) 설정 |
| **비밀** | sensitive = true, tfvars 미커밋, TF_VAR 또는 시크릿 저장소 | ⬜ 비밀 변수에 sensitive 추가, tfvars는 .gitignore |
| **환경 분리** | Workspace 또는 environments/ 디렉터리 | ⬜ tfvars로 분리 중이면 유지. 필요 시 environments/dev|prod 도입 |
| **스타일/검증** | fmt, validate | ⬜ CI 또는 pre-commit에 `terraform fmt -recursive`, `terraform validate` 추가 |

---

## 9. 공식 문서 링크

- [Standard Module Structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Backend configuration](https://developer.hashicorp.com/terraform/language/settings/backends/configuration)
- [State: Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Sensitive data in configuration](https://developer.hashicorp.com/terraform/language/state/sensitive-data)
- [Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [Learn Terraform recommended practices](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices)
- [Part 1: Recommended workflow overview](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part1)
- [Part 3.2: Move to infrastructure as code](https://developer.hashicorp.com/terraform/cloud-docs/recommended-practices/part3.2)
- [Project Best Practices (Terraform Cloud)](https://developer.hashicorp.com/terraform/cloud-docs/projects/best-practices)
- [Workspace Best Practices](https://developer.hashicorp.com/terraform/enterprise/workspaces/best-practices)

이 문서는 위 공식 문서를 요약·정리한 것이며, 최신 내용은 항상 HashiCorp 사이트에서 확인하는 것이 좋습니다.
