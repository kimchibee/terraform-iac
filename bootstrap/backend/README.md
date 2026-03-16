# Bootstrap (Backend Storage) 배포 가이드

Terraform State를 저장할 Backend(리소스 그룹, 스토리지 계정, 컨테이너)를 생성하는 스택입니다. **최초 1회만** 배포합니다.

---

## 0. 복사/붙여넣기용 배포 명령어 (최초 1회)

아래를 **순서대로** 터미널에 복사해 붙여넣기만 하면 됩니다. **프로젝트 루트**는 이 저장소(terraform-iac)의 최상위 디렉터리입니다.

**1단계: Bootstrap 디렉터리로 이동 후 변수 파일 복사**
```bash
cd bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
에디터로 `terraform.tfvars`를 열어 아래 표의 필수 항목을 채웁니다. (아래 "b. terraform.tfvars에서 필수로 작성해야 할 내용" 표 참고.)

**3단계: init / plan / apply (한 블록 통째로 복사 후 실행)**  
Bootstrap은 `backend.hcl`을 사용하지 않습니다. `terraform init`만 실행합니다.
```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 `yes` 입력.

**4단계: 각 스택용 backend.hcl 생성 (필수)**  
Bootstrap apply 완료 후, **프로젝트 루트**에서 아래 한 줄 실행.
```bash
cd ../..
./scripts/generate-backend-hcl.sh
```
이후 network, storage 등 각 스택에서 `terraform init -backend-config=backend.hcl` 후 plan/apply를 진행합니다.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `resource_group_name` | Backend용 리소스 그룹 이름 | 구독 내에서만 유일하면 됨. 예: `terraform-state-rg` |
| `storage_account_name` | State 저장용 스토리지 계정 이름 | **Azure 전역 고유** (소문자·숫자만, 3~24자, 하이픈 불가). 예: `tfstate` + 구독 ID 뒤 6자 (`tfstate07dc60`). 다른 사용자와 겹치면 생성 실패하므로 반드시 본인만의 이름으로 수정. |
| `container_name` | State Blob 컨테이너 이름 | 구독 내 유일. 기본값 `tfstate` 사용 가능. |
| `location` | Azure 리전 | 예: `Korea Central`. Azure Portal **리소스 그룹** 생성 시 선택하는 리전과 동일. |
| `tags` | (선택) 리소스 태그 | 기본값 있음. 필요 시 수정. |
| `subnet_id` | (선택) Private Endpoint용 서브넷 ID | 사용 시 VNet/서브넷 리소스 ID. 비우면 PE 미생성. |

**구독 ID 확인:** Azure Portal → **구독** → 사용할 구독 → **구독 ID**. 또는 `az account show --query id -o tsv`

**Backend 설정:** Bootstrap 스택은 **로컬 backend**로 초기화합니다(`terraform init`만 사용). `backend.hcl`은 사용하지 않습니다.

### c. 배포 실행 순서

```bash
cd bootstrap/backend
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### d. Bootstrap 배포 후: 각 스택용 backend.hcl 생성 (필수)

Bootstrap을 **apply**한 뒤, **network·storage·…·connectivity** 등 나머지 스택은 **원격 backend**를 사용합니다. 각 스택 디렉터리에 `backend.hcl`이 있어야 `terraform init -backend-config=backend.hcl`이 동작합니다.

**backend.hcl은 코드로 직접 작성하지 않고, 아래 스크립트로 한 번에 생성합니다.**  
(Bootstrap의 `terraform.tfvars`에서 `resource_group_name`, `storage_account_name`, `container_name`을 읽어 `azure/dev/*` 각 스택에 `backend.hcl`을 생성합니다.)

**프로젝트 루트(terraform-iac 최상위)에서 실행:**
```bash
./scripts/generate-backend-hcl.sh
```

- **실행 시점:** Bootstrap **apply 완료 후**, `bootstrap/backend/terraform.tfvars`가 준비된 상태에서 실행합니다.
- **생성 위치:** `azure/dev/01.network`, `azure/dev/02.storage`, `azure/dev/03.shared-services`, `azure/dev/04.apim`, `azure/dev/05.ai-services`, `azure/dev/06.compute`, `azure/dev/07.rbac`, `azure/dev/08.connectivity` 디렉터리에 각각 `backend.hcl`이 생성됩니다.
- **이후:** 각 스택에서 `terraform init -backend-config=backend.hcl` 후 plan/apply를 진행하면 됩니다.

---

## 2. 현 스택에서 다루는 리소스

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| Resource Group | Backend용 RG | 1 | `var.resource_group_name` 그대로 (예: `terraform-state-rg`) |
| Storage Account | State Blob 저장소 | 1 | `var.storage_account_name` 그대로. **전역 유일** (소문자·숫자 3~24자) |
| Storage Container | State 파일 컨테이너 | 1 | `var.container_name` (예: `tfstate`) |
| Private Endpoint | (선택) 스토리지 Blob PE | 0 또는 1 | `pe-${var.storage_account_name}`. `subnet_id`가 비어 있으면 미생성. |

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가

- Backend 스택은 보통 리소스 추가를 하지 않습니다.  
- 정말 추가할 경우(예: 두 번째 컨테이너): `main.tf`에 `resource` 블록 추가 후 `terraform plan` / `apply` 실행합니다.  
- **공통 모듈**을 쓰는 경우가 아니므로 모듈 레포 수정은 해당 없습니다.

### 3.2 기존 리소스 변경 (예: location, 태그, 스토리지 SKU)

1. `variables.tf` 또는 `terraform.tfvars`에서 값을 수정합니다.  
2. `terraform plan -var-file=terraform.tfvars`로 변경 내용 확인 후 `terraform apply -var-file=terraform.tfvars`로 적용합니다.  
3. **주의:** `resource_group_name` / `storage_account_name` / `container_name` 변경 시 기존 state가 있는 Backend를 바꾸게 되므로, state 이전(migrate) 또는 새 Backend 구축이 필요합니다. 보통은 이름 변경을 하지 않습니다.

### 3.3 기존 리소스 삭제

- Backend 리소스는 **lifecycle { prevent_destroy = true }** 로 보호되어 있어, `terraform destroy`로 삭제하려 하면 오류가 납니다.  
- 정말 제거할 때는 코드에서 `prevent_destroy` 제거 후 `terraform destroy`를 실행합니다.  
- **주의:** Backend를 삭제하면 **모든 스택의 state가 손실**되므로, 반드시 state 백업 후 진행합니다.

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

- Bootstrap 스택은 **모듈을 사용하지 않고** `main.tf`에 리소스만 정의되어 있습니다.  
- 따라서 이 스택에서는 **모듈 레포 수정 → init -upgrade** 절차가 필요 없습니다.  
- 다른 스택(network, storage, connectivity 등)에서 공통 모듈을 수정한 경우에는 해당 스택 README의 **「3.4 공통 모듈 수정이 필요한 경우」**를 따릅니다.
