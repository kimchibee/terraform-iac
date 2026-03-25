# Terraform IaC (Azure Hub-Spoke 인프라)

이 저장소는 **스택 분리 방식**으로 Azure Hub/Spoke 인프라를 관리합니다.  
각 스택은 **독립 State**를 가지며, **terraform-modules** 레포의 공통 모듈만 참조합니다.

---

## 1. 사용자 환경

배포 및 스크립트 실행에 필요한 환경입니다.

| 구분 | 요구 사항 |
|------|-----------|
| **Terraform** | **1.9.x 이상(권장: 1.9~1.10)**. 팀 내 동일 버전 사용 권장. [다운로드](https://www.terraform.io/downloads) |
| **Azure CLI** | 설치 후 `az login`으로 로그인. [설치 가이드](https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli) |
| **Bash** | `scripts/generate-backend-hcl.sh` 실행용. Windows는 Git Bash 또는 WSL 권장. |
| **OS** | Windows, macOS, Linux (Terraform·Azure CLI 지원 환경) |
| **Azure 구독** | Hub 구독 1개, Spoke 구독 1개 (동일 구독으로 Hub/Spoke 구성 가능) |
| **권한(구독)** | 각 구독에서 **Contributor 이상** + RBAC 생성 리프 실행 시 **User Access Administrator**(또는 Owner) |
| **권한(Entra ID)** | `07.identity`/`08.rbac` 실행 시 그룹 멤버십 변경 권한(예: **Groups Administrator** 이상) |
| **인증** | `az login` 또는 환경 변수: `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` |

- **Backend 저장소**: Terraform State용 Azure Storage Account·Container는 **Bootstrap** 스택으로 최초 1회 생성합니다.

### 1.1 신규 구독자 사전 체크리스트 (필수)

새 구독 ID를 가진 사용자가 처음 배포할 때, 아래를 먼저 준비합니다.

1. Azure 로그인/테넌트 확인
   - `az login`
   - `az account show --query "{name:name, id:id, tenantId:tenantId}" -o table`
2. Hub/Spoke 구독 ID 확보
   - `az account list --query "[].{name:name, id:id}" -o table`
3. 배포 권한 확인
   - Hub/Spoke 구독: `Contributor` 이상
   - `08.rbac` 적용 계정: `User Access Administrator` 또는 `Owner`
   - `07.identity`/`08.rbac`의 그룹 멤버십 변경: Entra ID 그룹 관리 권한
4. Backend 계획값 확정
   - `backend_resource_group_name`
   - `backend_storage_account_name` (전역 유일, 소문자/숫자 3~24자)
   - `backend_container_name` (기본 `tfstate`)
5. 공통 환경값 확정
   - `hub_subscription_id`, `spoke_subscription_id`
   - `project_name`, `environment`, `location`

> 권장: 위 값을 먼저 문서/메모에 확정한 뒤, 각 리프 `terraform.tfvars`에 동일하게 반영하세요.

---

## 2. modules / IaC 레포의 역할·정의·디렉토리 구조

### 2.1 역할과 정의

| 저장소 | 역할 | 정의 |
|--------|------|------|
| **terraform-iac** (이 레포) | **배포용** | `terraform init` / `plan` / `apply`를 실행하는 쪽. 스택별 디렉터리, Backend 설정, `terraform.tfvars`, 배포 순서가 여기 있음. |
| **terraform-modules** ([GitHub](https://github.com/kimchibee/terraform-modules)) | **공통 모듈** | AVM 기반 `resource-group`, `vnet`, `subnet`, `private-endpoint`, `api-management-service`, `cognitive-services-account`, `virtual-machine` 등 **재사용 모듈**만 보관. **apply는 하지 않음.** |

- **참조 방식**: terraform-iac의 각 스택은 `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=<branch-or-tag>"` 형태로 **Git 레포만** 참조합니다. 로컬 `modules/` 경로는 사용하지 않습니다.
- **AVM**: azurerm이 필수인 경우가 아니면 **Azure Verified Module(AVM)** 을 사용합니다.
- **모듈 버전 업데이트**: terraform-modules 쪽 코드나 `ref`를 바꾼 경우, 해당 스택에서 `terraform init -upgrade` 후 plan/apply
- **동기화 가이드**: 아키텍처 선배포 환경을 Terraform state로 동기화하는 절차는 `ARCHITECTURE_SYNC_SCENARIO_GUIDE.md` 참고

### 2.2 디렉토리 구조 (terraform-iac)

배포·관리 체계에 맞춘 실제 디렉터리 구조입니다. **plan/apply는 리프 폴더에서만** 실행합니다. (`01.network` 등 상위 폴더는 분류·README만 두는 경우가 많음.)

**강제 규칙**

- 상위 디렉토리는 **리소스 종류**로 나눕니다.
- 리프 디렉토리는 **리소스명**으로 만듭니다.
- 각 리프는 **자기 디렉토리 이름에 해당하는 리소스만** 관리합니다.
- `security-extension`, `common-extra` 같은 추상 디렉토리는 만들지 않습니다.
- 보안 리소스와 컴퓨트 리소스도 예외 없이 **자기 리소스 종류 아래, 자기 리소스명 리프**에서 관리합니다.
- NSG, ASG, rule, association 같은 리소스도 `network-security-group/<name>`, `application-security-group/<name>`처럼 **자기 리소스 기준**으로 분리합니다.
- 현재 구조는 `security-group/*`, `dns/*`, `subnet/*`, `route/*` 등 리소스 종류별 리프 분리 기준으로 운영합니다.

```
terraform-iac/
├── azure/dev/
│   ├── 01.network/
│   │   ├── vnet/
│   │   │   ├── hub-vnet/                # (1a) 리프 — Hub VNet, VPN, DNS, NSG (terraform-modules hub-vnet)
│   │   │   └── spoke-vnet/              # (1b) 리프 — Spoke VNet, PE NSG 등 (terraform-modules spoke-vnet)
│   │   ├── resource-group/              # (1a) hub-rg, spoke-rg
│   │   ├── subnet/                      # (1c) hub-*-subnet, spoke-*-subnet (`01.network/README.md`)
│   │   ├── security-group/
│   │   │   ├── application-security-group/  # (1d) keyvault-clients, vm-allowed-clients
│   │   │   ├── network-security-group/      # (1e) keyvault-standalone, hub-monitoring-vm, hub-pep, spoke-pep
│   │   │   ├── network-security-rule/       # NSG rule 리프
│   │   │   └── subnet-network-security-group-association/
│   │   ├── dns/
│   │   │   ├── private-dns-zone/
│   │   │   ├── private-dns-zone-vnet-link/
│   │   │   ├── dns-private-resolver/
│   │   │   └── dns-private-resolver-inbound-endpoint/
│   │   ├── route/                       # (1d) hub-route-default, spoke-route-default (선택)
│   │   ├── security-policy/             # (1e) hub-sg-policy-default, spoke-sg-policy-default (선택)
│   │   └── …                            # 기타 리소스 종류 리프 (`azure/dev/01.network/README.md`)
│   ├── 02.storage/
│   │   └── monitoring/                  # (2) 리프 — Key Vault, Monitoring Storage, PE (AVM wrapper 조합)
│   ├── 03.shared-services/
│   │   ├── log-analytics/               # (3a) 리프 — Log Analytics Workspace
│   │   └── shared/                      # (3b) 리프 — Solutions, Action Group, Dashboard (LA state 참조)
│   ├── 04.apim/
│   │   └── workload/                    # (4) 리프 — APIM (Git 모듈)
│   ├── 05.ai-services/
│   │   └── workload/                    # (5) 리프 — OpenAI, AI Foundry
│   ├── 06.compute/
│   │   ├── linux-monitoring-vm/         # (6) 리프 — Linux VM + MI
│   │   └── windows-example/            # (6) 리프 — Windows 예시 VM
│   ├── 07.identity/                     # (7) Entra 멤버십 — 리프 `group-membership/*`
│   ├── 08.rbac/                         # (8) Azure RBAC — 리프 `group/`, `principal/`, `authorization/` (`08.rbac/README.md`)
│   └── 09.connectivity/                 # (9) Peering·진단 — 리프 `peering/*`, `diagnostics/*` (`09.connectivity/README.md`)
├── bootstrap/backend/                  # Backend용 Storage Account·Container (최초 1회). backend.hcl 사용 안 함
├── scripts/
│   └── generate-backend-hcl.sh         # Bootstrap apply 후 실행 → 각 리프 디렉터리에 backend.hcl 생성 (`INFRA_LEAVES` 등)
├── config/                             # (선택) 정책·설정 예시 (acr-policy.json, apim-policy.xml, openai-deployments.json)
└── .github/workflows/                  # (선택) CI 워크플로
```

- **`01`~`06`도 동일 원칙**: 위 표의 **리프 경로**에 `main.tf` 등이 있으며, state 키는 `azure/dev/<리프 경로>/terraform.tfstate` 입니다. **`07.identity` / `08.rbac` / `09.connectivity`** 역시 리프별 독립 state입니다.
- **backend.hcl**은 저장소에 포함되지 않으며, **Bootstrap 적용 후** `./scripts/generate-backend-hcl.sh` 실행으로 각 스택 디렉터리에 생성됩니다.

**변수 관리 방식 (스택 공통)**  
- **루트**: 구독 ID, backend, location, tags, remote_state로 얻는 컨텍스트(리소스 그룹명·서브넷 ID 등)만 관리.  
- **하위 폴더**: 각 리소스의 **이름·사이즈·옵션**(주소 공간, 서브넷, 보존 일수, 역할 이름 등)은 **해당 폴더의 variables.tf 기본값**에서 관리.  
→ 신규 인스턴스 추가 시: **리프 복제 또는 신규 리프 생성** → **해당 리프의 variables/locals 기본값 수정** → **필요한 참조 output 추가** 순으로 반영합니다.

### 2.3 스택별 배포 리소스

각 스택이 생성·관리하는 Azure 리소스를 스택 기준으로 정리한 표입니다. (이름 예시는 `project_name` = `test` 기준, 접두사 `test-x-x`)

| 스택 | 구독 | 배포 리소스 |
|------|------|-------------|
| **Bootstrap** | Hub | Resource Group, Storage Account, Storage Container (Backend State용) |
| **network** | Hub | Resource Group, Virtual Network, Subnet(7종), VPN Gateway, Public IP, DNS Private Resolver, Private DNS Zone(14종), NSG, Private DNS Zone VNet Link |
| | Spoke | Resource Group, Virtual Network, Subnet(2종), NSG, Private DNS Zone(5종), Private DNS Zone VNet Link |
| **storage** | Hub | Key Vault, Storage Account(모니터링 로그용), Private Endpoint |
| **shared-services** | Hub | Log Analytics Workspace, Solutions, Action Group, Dashboard |
| **apim** | Spoke | API Management, 관련 Private Endpoint·DNS |
| **ai-services** | Spoke | Azure OpenAI, AI Foundry(ML Workspace), AI Foundry 의존 리소스(Storage/Key Vault/Log Analytics/App Insights), 관련 Private Endpoint |
| **compute** | Hub | Linux VM(Monitoring), Windows VM(예시), Managed Identity |
| **rbac** | Hub/Spoke | Role Assignment (Monitoring VM, 그룹 역할) + 그룹 멤버십 등록·변경·삭제(Terraform) |
| **connectivity** | Hub(주로) / Spoke(피어링 한쪽) | VNet Peering(Hub↔Spoke), Hub 진단 설정 — 리프별 state (`09.connectivity/README.md`) |

- 상세 리소스 이름·서브넷 목록은 각 스택 디렉터리의 `README.md`(예: `azure/dev/01.network/README.md`, `azure/dev/06.compute/README.md`)를 참고하세요.

### 2.4 스택별 azurerm / AVM 참조

- **azurerm (루트/로컬에서 직접)**: 해당 스택의 루트 또는 로컬 모듈에서 `resource "azurerm_*"` / `data "azurerm_*"`를 직접 사용하는지 여부.
- **AVM (모듈)**: AVM을 통해 모듈을 사용하는지. 데이터 저장·모듈화 등으로 azurerm을 함께 쓰는 경우도 있음.

| 스택 | azurerm (루트/리프에서 직접) | AVM (모듈) | 현황 비고 |
|------|:---------------------------:|:----------:|------|
| **network** | ✅ | ✅ | `security-group/*`, `dns/*`, `subnet/*`, `vnet/*`, `route/*` 리프 조합으로 운영 |
| **storage** | ✅ | ✅ | `monitoring` 리프에서 AVM wrapper + azurerm data/resource 병행 |
| **shared-services** | ✅ | ✅ | `log-analytics`는 AVM wrapper 중심, `shared`는 운영 리소스 조합 |
| **apim** | ✅ | ✅ | `api-management-service` 모듈 + 리프 오케스트레이션 |
| **ai-services** | ✅ | ✅ | `cognitive-services-account`, `private-endpoint` 모듈 + ML Workspace 의존 리소스 직접 관리 |
| **compute** | ✅ | ✅ | `virtual-machine` 모듈 사용, 리프에서 NIC/ASG/identity 참조 오케스트레이션 |
| **identity/rbac** | ✅ | ❌ | Entra/Azure RBAC 리소스 직접 관리 (`azuread_*`, `azurerm_role_assignment`) |
| **connectivity** | ✅ | ✅ | `diagnostics/hub`는 azurerm, `peering/*`는 `vnet-peering` 모듈 |

---

## 3. 초기 배포 작업 순서

전체 흐름: **Bootstrap → backend.hcl 생성 스크립트 실행 → 각 스택을 순서대로 배포**합니다.

- **점검 기준표**: 배포 시 스택별 검증 항목은 `docs/DEPLOYMENT_VERIFICATION_CHECKLIST.md`(해당 파일이 있는 경우) 참고.
- **배포 순서별 명령어**: 복사·실행용 명령어 목록은 `docs/DEPLOYMENT_COMMANDS.md`(해당 파일이 있는 경우) 참고.  
  없으면 각 스택 README의 **「0. 복사/붙여넣기용 배포 명령어」** 를 순서대로 따라가면 됩니다.

### 3.0 사전 준비

- **구독 ID**: Hub/Spoke 구독 ID를 확인한 뒤, 각 스택의 `terraform.tfvars`에 `hub_subscription_id`, `spoke_subscription_id`를 넣습니다.  
  - 확인: `az account list --query "[].{name:name, id:id}" -o table`  
  - 동일 구독 사용 시 두 값에 같은 ID 입력.
- **Backend Storage 이름**: `bootstrap/backend/terraform.tfvars`의 `storage_account_name`은 **Azure 전역 유일**(소문자·숫자 3~24자, 하이픈 불가)이어야 하므로, 다른 사용자와 겹치지 않게 수정합니다.
- **각 스택 terraform.tfvars**: network 이후 스택은 **Bootstrap 출력값**을 변수로 넣어야 합니다. `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name`을 Bootstrap의 `terraform.tfvars`(또는 `terraform output`)와 동일하게 맞추세요. 예시는 각 스택의 `terraform.tfvars.example`에 있습니다.

### 3.0.0 구독 ID 입력 대상 tfvars 경로

- 자동화용 JSON 목록: `scripts/subscription-tfvars-paths.json`
- Bootstrap 기준값 파일: `bootstrap/backend/terraform.tfvars`

```text
azure/dev/01.network/resource-group/hub-rg/terraform.tfvars
azure/dev/01.network/resource-group/spoke-rg/terraform.tfvars
azure/dev/01.network/vnet/hub-vnet/terraform.tfvars
azure/dev/01.network/vnet/spoke-vnet/terraform.tfvars
azure/dev/01.network/subnet/hub-appgateway-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-azurefirewall-management-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-azurefirewall-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-dnsresolver-inbound-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-gateway-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-monitoring-vm-subnet/terraform.tfvars
azure/dev/01.network/subnet/hub-pep-subnet/terraform.tfvars
azure/dev/01.network/subnet/spoke-apim-subnet/terraform.tfvars
azure/dev/01.network/subnet/spoke-pep-subnet/terraform.tfvars
azure/dev/01.network/dns/private-dns-zone/hub-blob/terraform.tfvars
azure/dev/01.network/route/hub-route-default/terraform.tfvars
azure/dev/01.network/route/spoke-route-default/terraform.tfvars
azure/dev/01.network/security-group/application-security-group/keyvault-clients/terraform.tfvars
azure/dev/01.network/security-group/application-security-group/vm-allowed-clients/terraform.tfvars
azure/dev/01.network/security-group/network-security-group/hub-monitoring-vm/terraform.tfvars
azure/dev/01.network/security-group/network-security-group/hub-pep/terraform.tfvars
azure/dev/01.network/security-group/network-security-group/keyvault-standalone/terraform.tfvars
azure/dev/01.network/security-group/network-security-group/spoke-pep/terraform.tfvars
azure/dev/01.network/security-group/security-policy/hub-sg-policy-default/terraform.tfvars
azure/dev/01.network/security-group/security-policy/spoke-sg-policy-default/terraform.tfvars
azure/dev/02.storage/monitoring/terraform.tfvars
azure/dev/03.shared-services/log-analytics/terraform.tfvars
azure/dev/03.shared-services/shared/terraform.tfvars
azure/dev/04.apim/workload/terraform.tfvars
azure/dev/05.ai-services/workload/terraform.tfvars
azure/dev/06.compute/linux-monitoring-vm/terraform.tfvars
azure/dev/06.compute/windows-example/terraform.tfvars
azure/dev/08.rbac/authorization/hub-assignments/terraform.tfvars
azure/dev/08.rbac/authorization/spoke-assignments/terraform.tfvars
azure/dev/08.rbac/group/admin-hub-scope/terraform.tfvars
azure/dev/08.rbac/group/ai-developer-spoke-scope/terraform.tfvars
azure/dev/08.rbac/principal/hub-assignments/terraform.tfvars
azure/dev/08.rbac/principal/spoke-assignments/terraform.tfvars
azure/dev/09.connectivity/diagnostics/hub/terraform.tfvars
azure/dev/09.connectivity/peering/hub-to-spoke/terraform.tfvars
azure/dev/09.connectivity/peering/spoke-to-hub/terraform.tfvars
```

### 3.0.1 구독 2개로 운영할 때 (Hub / Spoke 분리)

아키텍처상 **Hub 구독**과 **Spoke 구독**을 나누어 배포하려면 아래 순서로 진행하면 됩니다.

1. **Azure에서 구독 2개 확보**  
   - [Azure Portal](https://portal.azure.com) → **구독** → 구독 추가(또는 EA/MCA에서 구독 생성).  
   - 예: "Hub-Prod", "Spoke-Prod" 처럼 Hub용 1개, Spoke용 1개를 미리 만듭니다.

2. **구독 ID 확인**  
   ```bash
   az login
   az account list --query "[].{name:name, id:id, state:state}" -o table
   ```  
   - 사용할 Hub 구독 ID, Spoke 구독 ID를 복사해 둡니다.  
   - [Portal] 구독 → 해당 구독 선택 → **개요** 의 **구독 ID**에서 복사해도 됩니다.

3. **Bootstrap 배포 (구독 ID 입력 없음)**  
   - Bootstrap 스택에는 **구독 ID 변수가 없습니다.**  
   - **Terraform State를 둘 구독 1개**를 선택한 뒤, 그 구독에서 Bootstrap을 실행합니다.  
   - 보통 **Hub 구독**에 Backend를 두는 경우가 많습니다.  
   ```bash
   az account set --subscription "<Hub 구독 ID>"
   cd bootstrap/backend
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars 편집: resource_group_name, storage_account_name, container_name, location 등 (구독 ID는 없음)
   terraform init
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```  
   - 이후 프로젝트 루트에서 `./scripts/generate-backend-hcl.sh` 실행.

4. **Network 이후 각 스택: 구독 ID 입력**  
   - **network** ~ **connectivity** 각 스택의 `terraform.tfvars`에 다음을 넣습니다.  
   - `hub_subscription_id` = 위에서 확인한 **Hub 구독 ID**  
   - `spoke_subscription_id` = 위에서 확인한 **Spoke 구독 ID**  
   - 각 스택 디렉터리에서 `cp terraform.tfvars.example terraform.tfvars` 후, 두 값을 본인 구독 ID로 채우면 됩니다.

5. **두 구독 모두**  
   - [3.1 구독 Resource Provider 필수 등록](#31-구독-resource-provider-필수-등록)을 **Hub·Spoke 구독 각각**에서 실행합니다.  
   - 배포하는 계정은 두 구독 모두 **Contributor** 또는 **Owner** 권한이 있어야 합니다.

**한 구독으로만 테스트할 때**: Hub와 Spoke를 같은 구독에 두려면, `hub_subscription_id`와 `spoke_subscription_id`에 **같은 구독 ID**를 넣으면 됩니다. VNet만 구분되고 리소스는 한 구독에 모두 생성됩니다.

### 3.0.2 신규 구독자용 복사/붙여넣기 배포 매뉴얼 (Bootstrap부터)

아래 순서는 신규 구독 ID 사용자가 **현재 상태를 처음부터 재현**할 때 기준입니다.  
핵심 원칙은 **Bootstrap -> backend.hcl 생성 -> 우선순위 리프 순차 적용**입니다.

#### Step A. 공통 값 선언 (PowerShell)

```powershell
# 1) 본인 값으로 교체
$HUB_SUBSCRIPTION_ID   = "<hub-subscription-id>"
$SPOKE_SUBSCRIPTION_ID = "<spoke-subscription-id>"
$BACKEND_RG            = "terraform-state-rg"
$BACKEND_SA            = "tfstatexxxxxxxx"
$BACKEND_CONTAINER     = "tfstate"
$LOCATION              = "Korea Central"
$PROJECT_NAME          = "test"
$ENVIRONMENT           = "dev"
```

#### Step B. Bootstrap 배포 (최초 1회)

```powershell
Set-Location "<repo-root>/bootstrap/backend"
Copy-Item "terraform.tfvars.example" "terraform.tfvars" -Force

# terraform.tfvars에 아래 값 반영
# - resource_group_name
# - storage_account_name
# - container_name
# - location

terraform init
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

#### Step C. backend.hcl 생성

```bash
# Git Bash/WSL
cd "<repo-root>"
./scripts/generate-backend-hcl.sh
```

PowerShell만 사용할 경우 각 리프에 아래 형식으로 수동 생성:

```hcl
resource_group_name  = "<BACKEND_RG>"
storage_account_name = "<BACKEND_SA>"
container_name       = "<BACKEND_CONTAINER>"
key                  = "azure/dev/<leaf-path>/terraform.tfstate"
```

#### Step C-1. 전체 스택 자동 배포 스크립트 (선택)

아래 스크립트는 구독 ID 입력을 받아 `terraform.tfvars`를 일괄 갱신하고, `01.network`부터 `09.connectivity`까지 순차 배포합니다.
로그는 `scripts/logs/deploy-<timestamp>/`에 저장되며 터미널에도 동시에 출력됩니다.

```bash
cd "<repo-root>"
bash ./scripts/deploy-stacks-sequential.sh
```

#### Step D. Provider 등록 (Hub/Spoke 각각 실행)

```powershell
$namespaces = @(
  "Microsoft.OperationalInsights",
  "Microsoft.Insights",
  "Microsoft.OperationsManagement",
  "Microsoft.ApiManagement",
  "Microsoft.Network",
  "Microsoft.Storage",
  "Microsoft.KeyVault",
  "Microsoft.Compute",
  "Microsoft.CognitiveServices",
  "Microsoft.MachineLearningServices"
)

foreach ($sub in @($HUB_SUBSCRIPTION_ID, $SPOKE_SUBSCRIPTION_ID)) {
  az account set --subscription $sub
  foreach ($ns in $namespaces) { az provider register --namespace $ns | Out-Null }
}
```

#### Step E. 우선순위 순서대로 리프 배포

아래 순서가 현재 레포의 의존성 기준 우선순위입니다.

1) `01.network`
- `azure/dev/01.network/resource-group/hub-rg`
- `azure/dev/01.network/security-group/application-security-group/keyvault-clients`
- `azure/dev/01.network/security-group/application-security-group/vm-allowed-clients`
- `azure/dev/01.network/security-group/network-security-group/keyvault-standalone`
- `azure/dev/01.network/vnet/hub-vnet`
- `azure/dev/01.network/subnet/hub-gateway-subnet`
- `azure/dev/01.network/subnet/hub-dnsresolver-inbound-subnet`
- `azure/dev/01.network/subnet/hub-azurefirewall-subnet`
- `azure/dev/01.network/subnet/hub-azurefirewall-management-subnet`
- `azure/dev/01.network/subnet/hub-appgateway-subnet`
- `azure/dev/01.network/subnet/hub-monitoring-vm-subnet`
- `azure/dev/01.network/subnet/hub-pep-subnet`
- `azure/dev/01.network/resource-group/spoke-rg`
- `azure/dev/01.network/vnet/spoke-vnet`
- `azure/dev/01.network/subnet/spoke-apim-subnet`
- `azure/dev/01.network/subnet/spoke-pep-subnet`
- `azure/dev/01.network/route/hub-route-default`
- `azure/dev/01.network/route/spoke-route-default`

2) `02.storage`
- `azure/dev/02.storage/monitoring`

3) `03.shared-services`
- `azure/dev/03.shared-services/log-analytics`
- `azure/dev/03.shared-services/shared`

4) `04.apim`
- `azure/dev/04.apim/workload`

5) `05.ai-services`
- `azure/dev/05.ai-services/workload`

6) `06.compute`
- `azure/dev/06.compute/linux-monitoring-vm`
- `azure/dev/06.compute/windows-example`

7) `07.identity`
- `azure/dev/07.identity/group-membership/admin-core`
- `azure/dev/07.identity/group-membership/ai-developer-core`

8) `08.rbac`
- `azure/dev/08.rbac/group/admin-hub-scope`
- `azure/dev/08.rbac/group/ai-developer-spoke-scope`
- `azure/dev/08.rbac/principal/hub-assignments`
- `azure/dev/08.rbac/principal/spoke-assignments`
- `azure/dev/08.rbac/authorization/hub-assignments`
- `azure/dev/08.rbac/authorization/spoke-assignments`

9) `09.connectivity`
- `azure/dev/09.connectivity/diagnostics/hub`
- `azure/dev/09.connectivity/peering/hub-to-spoke`
- `azure/dev/09.connectivity/peering/spoke-to-hub`

각 리프 공통 명령 (복붙):

```powershell
Set-Location "<repo-root>/<leaf-path>"
if ((Test-Path "terraform.tfvars.example") -and !(Test-Path "terraform.tfvars")) {
  Copy-Item "terraform.tfvars.example" "terraform.tfvars"
}

# terraform.tfvars에 최소 반영:
# - hub_subscription_id / spoke_subscription_id
# - backend_resource_group_name / backend_storage_account_name / backend_container_name
# - project_name / environment / location (해당 리프에서 사용 시)

terraform init -backend-config backend.hcl
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

> 운영 팁: `03.shared-services/shared`, `04.apim/workload`, `05.ai-services/workload`는 생성 시간이 길 수 있으므로 중간 실패 시 [3.2.1](#321-실배포-기준-오류-대응) 패턴으로 즉시 복구 후 재실행하세요.

### 3.1 구독 Resource Provider 필수 등록

배포 전에 아래 Provider를 구독에 등록합니다. 미등록 시 `MissingSubscriptionRegistration`(409) 오류가 발생할 수 있습니다.

```bash
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.MachineLearningServices
```

**등록 완료 확인** (Registered 나올 때까지 대기):

```bash
az provider show --namespace Microsoft.OperationalInsights --query "registrationState" -o tsv
# 필요 시 다른 namespace도 동일하게 확인
```

### 3.2 배포 순서 및 스택별 배포 내용 요약

| 순서 | 스택 | 디렉터리 | 배포 리소스명(예: project_name=test) | 비고 |
|------|------|----------|--------------------------------------|------|
| 0 | Bootstrap | `bootstrap/backend` | Resource Group, Storage Account, Storage Container (이름은 terraform.tfvars 기준) | Backend State용. **최초 1회.** `terraform init`만 사용(backend.hcl 없음). |
| - | **backend.hcl 생성** | 프로젝트 루트 | — | Bootstrap **apply 완료 후** Bash 환경에서 `./scripts/generate-backend-hcl.sh` 실행. (Windows PowerShell 단독 환경이면 [3.2.1](#321-실배포-기준-오류-대응)를 참고해 `backend.hcl`을 리프별로 동일 값으로 생성) |
| 1a | network-rg-hub | `azure/dev/01.network/resource-group/hub-rg` | Hub Resource Group | 최우선 |
| 1b | network-asg-hub | `azure/dev/01.network/security-group/application-security-group/keyvault-clients`, `.../vm-allowed-clients` | Hub ASG 리프 | hub-rg 이후 |
| 1c | network-nsg-hub | `azure/dev/01.network/security-group/network-security-group/keyvault-standalone` | Hub standalone NSG | hub-rg 이후 |
| 1d | network-vnet-hub | `azure/dev/01.network/vnet/hub-vnet` | Hub VNet·VPN·DNS(모듈) | hub-rg 이후 |
| 1e | network-subnet-hub-leaves | `azure/dev/01.network/subnet/hub-gateway-subnet`, `hub-dnsresolver-inbound-subnet`, `hub-azurefirewall-subnet`, `hub-azurefirewall-management-subnet`, `hub-appgateway-subnet`, `hub-monitoring-vm-subnet`, `hub-pep-subnet` | Hub 서브넷 리프 | hub-vnet 이후 |
| 1f | network-rg-spoke | `azure/dev/01.network/resource-group/spoke-rg` | Spoke Resource Group | hub 이후 |
| 1g | network-vnet-spoke | `azure/dev/01.network/vnet/spoke-vnet` | Spoke VNet·DNS | spoke-rg 이후 |
| 1h | network-subnet-spoke-leaves | `azure/dev/01.network/subnet/spoke-apim-subnet`, `azure/dev/01.network/subnet/spoke-pep-subnet` | Spoke 서브넷 리프 | spoke-vnet 이후 |
| 1i | network-route-* | `azure/dev/01.network/route/hub-route-default` · `.../route/spoke-route-default` | Hub/Spoke UDR(모니터링↔워크로드 경로, NVA 시) | vnet 이후 |
| 2 | storage | `azure/dev/02.storage/monitoring` | Key Vault, Monitoring Storage, Private Endpoint | state는 monitoring 리프 |
| 3 | shared-services | `azure/dev/03.shared-services/log-analytics` → `.../shared` | LA → Action Group·Dashboard 순으로 적용 | 리프 2개 |
| 4 | apim | `azure/dev/04.apim/workload` | API Management 및 관련 PE·DNS | workload 리프 |
| 5 | ai-services | `azure/dev/05.ai-services/workload` | OpenAI, AI Foundry 등 | workload 리프 |
| 6 | compute | `azure/dev/06.compute/linux-monitoring-vm`, `.../windows-example` | Linux/Windows VM, Managed Identity | VM별 리프 |
| 7 | identity | `azure/dev/07.identity/...` | Entra 멤버십 | **배포 순서상 `08.rbac`보다 앞(선택)** |
| 8 | rbac | `azure/dev/08.rbac/...` | 그룹·주체·authorization 역할 | `08.rbac/README.md` |
| 9 | connectivity | `azure/dev/09.connectivity/...` | Peering, 진단 설정 | `09.connectivity/README.md` |

**각 스택 공통 절차:**

```bash
cd azure/dev/01.network/vnet/hub-vnet   # 또는 각 스택 리프 경로
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 (구독 ID, backend 관련 변수 등)
terraform init -backend-config backend.hcl
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

```powershell
Set-Location "azure/dev/01.network/vnet/hub-vnet"   # 또는 각 스택 리프 경로
Copy-Item "terraform.tfvars.example" "terraform.tfvars"
# terraform.tfvars 편집 (구독 ID, backend 관련 변수 등)
terraform init -backend-config backend.hcl
terraform plan -var-file terraform.tfvars
terraform apply -var-file terraform.tfvars
```

- **backend.hcl**은 `./scripts/generate-backend-hcl.sh` 실행으로 생성됩니다. 수동 작성 방법은 **Bootstrap 스택 README** (`bootstrap/backend/README.md`)를 참고하세요.
- **삭제(롤백) 시**: **배포의 역순**이 안전합니다. **`09.connectivity` 각 리프** → `08.rbac`·`07.identity` 각 리프 → `06.compute` VM 리프 → … → `01.network/route/*` → `01.network/security-policy/*` → `01.network/subnet/spoke-*` → `01.network/vnet/spoke-vnet` → `01.network/resource-group/spoke-rg` → `01.network/subnet/hub-*` → `01.network/vnet/hub-vnet` → `01.network/network-security-group/*` → `01.network/application-security-group/*` → `01.network/resource-group/hub-rg`. 세부는 `01.network/README.md`, `08.rbac/README.md`, `09.connectivity/README.md` 참고.

### 3.2.1 실배포 기준 오류 대응

실제 배포(`network -> connectivity`)에서 반복 확인된 오류와 대응 절차입니다.

| 오류 증상 | 대표 메시지 | 대응 방법 |
|------|------|------|
| 리소스는 Azure에 이미 있는데 state가 비어 있음 | `A resource with the ID ... already exists - ... import into the State` | 해당 리프에서 `terraform import <address> <resource_id>`로 state 복구 후 재실행 |
| Terraform 옵션 파싱 오류 | `Too many command line arguments` | `-backend-config=backend.hcl`, `-var-file=terraform.tfvars` 대신 **공백 구문** 사용 (`-backend-config backend.hcl`, `-var-file terraform.tfvars`) |
| PowerShell에서 bash 스크립트 미실행 | `'bash' is not recognized` | Git Bash/WSL에서 `./scripts/generate-backend-hcl.sh` 실행 또는 리프별 `backend.hcl` 수동 생성 |
| 선행 state/output 부재 | `outputs is object with no attributes`, `Unsupported attribute` | 선행 리프가 apply되어 state output이 생성됐는지 확인 후 순서 재실행 |
| provider 버전 충돌 | `no available releases match the given constraints ~> 3.75.0, ~> 4.0` | 리프와 참조 모듈의 `required_providers` 제약을 단일 메이저로 정렬(예: `~> 4.0`) 후 `terraform init -upgrade` |

#### 수동 backend.hcl 템플릿 (PowerShell 단독 환경용)

각 리프 디렉터리의 `backend.hcl`을 아래 형식으로 동일하게 맞춥니다. (`key`만 리프 경로에 맞게 변경)

```hcl
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstate7dc60879"
container_name       = "tfstate"
key                  = "azure/dev/<leaf-path>/terraform.tfstate"
```

#### 동일 이슈 재발 시 공통 적용 규칙 (다른 스택 포함)

`01.network`에서 검증된 아래 순서를 `02~09` 스택에도 동일하게 적용합니다.

1. provider 충돌 발생 시: 리프/래퍼/AVM 제약 교집합을 확인해 한 메이저로 정렬 후 `terraform init -upgrade`
2. `backend.hcl` 누락 시: 위 템플릿으로 생성하고 `key`만 리프 경로에 맞게 변경
3. `resource already exists` 발생 시: `terraform import <address> <resource_id>` 후 `plan/apply` 재실행
4. `Unsupported attribute`/`outputs is object with no attributes` 발생 시: 선행 의존 리프 먼저 적용 후 하위 리프 재실행
5. 리프별 기본 점검 순서: `resource-group -> vnet -> nsg -> subnet -> route -> security-policy`

### 3.3 AI 모델 지정 방법 가이드 (ai-services 스택)

- **Azure OpenAI 모델 배포**는 리전별 **쿼터**가 필요합니다. 쿼터 없으면 `InsufficientQuota` 오류가 발생합니다.
- 일부 모델은 구독/리전 조합에 따라 **추가 기능 승인(feature enablement)** 이 필요할 수 있습니다. `SpecialFeatureOrQuotaIdRequired` 오류가 나오면 Azure 지원 경로로 해당 모델 feature 활성화 요청을 진행하세요.
- **쿼터 승인 전**: `azure/dev/05.ai-services/workload/terraform.tfvars`에서 `openai_deployments = []` 로 두고 배포하면 **모델 배포 없이** AI Foundry, Private Endpoints 등만 생성됩니다.
- **쿼터 승인 후** 모델을 배포하려면:

1. **쿼터 확인**  
   `az cognitiveservices usage list --location koreacentral -o table`  
   쿼터 요청: [https://aka.ms/oai/stuquotarequest](https://aka.ms/oai/stuquotarequest)

2. **변수 수정**  
   `azure/dev/05.ai-services/workload/terraform.tfvars`에서:
   - `openai_deployments = []` 를 제거하고
   - 사용할 모델 블록을 아래 형식으로 추가합니다.

   ```hcl
   openai_deployments = [
     { name = "gpt-4o",       model_name = "gpt-4o",       version = "2024-05-13", capacity = 30 }
     { name = "gpt-4o-mini", model_name = "gpt-4o-mini", version = "2024-07-18", capacity = 10 }
     # name: 배포 이름, model_name: 모델 ID, version: API 버전, capacity: TPM 등 용량
   ]
   ```

3. **재적용**  
   `cd azure/dev/05.ai-services` 후 `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`

- 예시와 상세 옵션은 `azure/dev/05.ai-services/workload/terraform.tfvars.example` 및 `docs/AZURE-OPENAI-QUOTA-AND-MODELS.md`(있는 경우)를 참고하세요.

### 3.4 아키텍처 선배포 환경 동기화 가이드

이미 Azure에 리소스가 배포된 상태(아키텍처 기준)에서 현재 Terraform 코드와 state를 동기화해야 하는 경우, 아래 문서를 기준으로 진행합니다.

- `ARCHITECTURE_SYNC_SCENARIO_GUIDE.md`

핵심 목적(중요):

- **목표는 import 자체가 아니라, 현재 콘솔(수동)로 운영 중인 시스템 구성과 Terraform 코드를 먼저 일치시키는 것**입니다.
- 즉, "기존 리소스는 무조건 import"가 아니라 아래 순서로 **코드 정합화 -> 상태 동기화 -> Terraform-only 운영 전환**을 수행합니다.

권장 절차:

1. **현행 아키텍처 기준선 확정**  
   - 실제 운영 리소스(이름, SKU, 네트워크 연결, 권한)를 먼저 기준선으로 확정합니다.
2. **코드 정합화 선행**  
   - `variables.tf`, `terraform.tfvars`, `locals`를 먼저 수정해 Terraform 코드가 운영 현실과 동일하게 해석되도록 맞춥니다.
   - 운영 영향이 큰 리소스는 이름 변경보다 코드/변수를 현실에 맞추는 것을 우선합니다.
3. **상태 동기화(state) 수행**  
   - 코드 기준과 실제 리소스가 맞는 항목만 `import`로 state에 편입합니다.
   - Terraform 관리 대상에서 제외할 항목은 리프 분리 또는 enable 플래그로 비활성화해 관리 경계를 명확히 합니다.
4. **전환 검증 후 Terraform-only 적용**  
   - 각 리프 `plan`이 무변경(또는 의도 변경)임을 확인한 뒤, 신규 리소스 생성/변경은 Terraform으로만 수행합니다.
5. **최종 검증**  
   - 피어링, NSG/ASG, Private Endpoint, remote state output 참조까지 전체 점검합니다.

---

## 4. 배포 완료 후 전체 아키텍처 구조

배포가 끝나면 아래와 같은 Hub-Spoke 구조가 만들어집니다.

- **Hub 구독** (`test-x-x-rg`): Hub VNet, VPN Gateway(Site-to-Site), DNS Private Resolver, Key Vault, Monitoring Storage(진단 로그용), Monitoring VM, Log Analytics, Shared Services(Solutions, Action Group, Dashboard).  
  **Spoke 구독** (`test-x-x-spoke-rg`): Spoke VNet, API Management, Azure OpenAI, Azure AI Foundry, 각 서비스용 Private Endpoint 및 Private DNS Zone.
- **연결**: VNet Peering (Hub ↔ Spoke), Spoke 쪽 Private DNS Zone 링크는 Hub에서 생성한 Zone을 사용.

개요만 보면 (서브넷 구분 포함):

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                     Hub Subscription (test-x-x-rg) · Hub VNet                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│  GatewaySubnet          │ VPN Gateway, Public IP                                 │
│  DNSResolver-Inbound    │ DNS Private Resolver (Inbound)                          │
│  AzureFirewallSubnet    │ (선택) Azure Firewall                                   │
│  AzureFirewallMgmtSubnet│ (선택) Azure Firewall 관리                              │
│  AppGatewaySubnet       │ (선택) Application Gateway                              │
│  Monitoring-VM-Subnet   │ Linux Monitoring VM, Windows VM                         │
│  pep-snet               │ Key Vault PE, Storage PE (Private Endpoint)              │
├─────────────────────────────────────────────────────────────────────────────────┤
│  기타: Key Vault, Monitoring Storage, Log Analytics, Shared Services             │
└─────────────────────────────────────────────────────────────────────────────────┘
                                        │ VNet Peering
┌───────────────────────────────────────┴───────────────────────────────────────────┐
│                 Spoke Subscription (test-x-x-spoke-rg) · Spoke VNet              │
├─────────────────────────────────────────────────────────────────────────────────┤
│  apim-snet   │ API Management                                                    │
│  pep-snet    │ APIM / OpenAI / AI Foundry 등 Private Endpoint                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│  기타: Azure OpenAI, AI Foundry(ML Workspace), Private DNS Zone(5종)              │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 배포 검증 (선택)

apply 후 리소스가 생성되었는지 확인하려면:

```bash
az group list --query "[?contains(name,'test-x-x') || contains(name,'terraform-state')].{name:name, location:location}" -o table
az network vnet peering list --resource-group "test-x-x-rg" --vnet-name "test-x-x-vnet" -o table
```

Peering이 **Connected**이면 정상입니다.

---

## 5. Pilot: 새 VNet + Linux 서버 + Hub Key Vault 접근 (방화벽·권한)

**목표:** 새로운 Spoke VNet을 만들고, 그 위에 Linux 서버를 배치한 뒤, Hub 서브넷(pep-snet)에 있는 Key Vault로 접속 가능하도록 **방화벽(NSG/ASG)** 및 **권한(RBAC)** 을 추가하는 데 필요한 **복제할 폴더**와 **수정·추가할 파일/코드**를 정리한 가이드입니다.

### 5.1 요약: 복제 폴더 및 수정 파일

| 순서 | 작업 | 복제할 폴더 | 수정·추가할 파일 |
|------|------|-------------|------------------|
| 1 | 새 Spoke VNet | `01.network/vnet/spoke-vnet/spoke-vnet` → `spoke-vnet-pilot` | `spoke-vnet-pilot/variables.tf`, `vnet/spoke-vnet/main.tf`, `vnet/spoke-vnet/outputs.tf` |
| 2 | 방화벽(Key Vault 접근) | (없음) | `01.network/terraform.tfvars` |
| 3 | 새 Linux 서버(Spoke 배치) | `06.compute/linux-monitoring-vm` → `06.compute/linux-pilot-vm` | `linux-pilot-vm/variables.tf`, `06.compute/main.tf`, `06.compute/outputs.tf` |
| 4 | Key Vault 권한(RBAC) | (없음) | `08.rbac/main.tf` |

**적용 순서:** `01.network/resource-group/hub-rg` → `01.network/application-security-group/keyvault-clients`·`vm-allowed-clients` → `01.network/network-security-group/keyvault-standalone` → `01.network/vnet/hub-vnet` → `01.network/subnet/hub-gateway-subnet` 등 Hub 서브넷 리프 → `01.network/subnet/hub-pep-subnet` → `01.network/resource-group/spoke-rg` → `01.network/vnet/spoke-vnet` → `01.network/subnet/spoke-apim-subnet`·`spoke-pep-subnet` → `01.network/route/hub-route-default`·`route/spoke-route-default`(선택) → `02.storage/monitoring` → `03.shared-services/*` → … → `06.compute/*` VM 리프 → `07.identity`(선택) → `08.rbac` → `09.connectivity`.

### 5.2 새 VNet (Spoke Pilot) 추가

#### 폴더 복제

```bash
cd azure/dev/01.network/vnet/spoke-vnet
cp -r spoke-vnet spoke-vnet-pilot
```

- 복제 결과: `azure/dev/01.network/vnet/spoke-vnet/spoke-vnet-pilot/` (내부 파일 구조는 `spoke-vnet`과 동일)

#### 수정: `azure/dev/01.network/vnet/spoke-vnet/spoke-vnet-pilot/variables.tf`

**역할:** 이 Spoke만의 리소스 정보(RG·VNet·서브넷)를 기본값으로 정의. 복제본이므로 **아래 변수의 기본값만** Pilot용으로 바꿉니다.

| 변수 | 수정 예시 | 설명 |
|------|-----------|------|
| `rg_suffix` | `"pilot-rg"` | Pilot 전용 Resource Group 접미사 |
| `vnet_suffix` | `"pilot-vnet"` | Pilot VNet 이름 접미사 |
| `vnet_address_space` | `["10.2.0.0/24"]` | Pilot VNet CIDR (기존 Spoke와 겹치지 않게) |
| `subnets` | Pilot Linux 서버용 서브넷 1개 이상 | 서브넷 이름·주소·필요 시 service_endpoints |

**예시 코드 (기본값만 변경):**

```hcl
#--------------------------------------------------------------
# 이 Spoke(Pilot)의 리소스 정보
#--------------------------------------------------------------
variable "rg_suffix" {
  description = "Resource Group 이름 접미사 (최종 이름: name_prefix-rg_suffix)"
  type        = string
  default     = "pilot-rg"
}

variable "vnet_suffix" {
  description = "VNet 이름 접미사 (최종 이름: name_prefix-vnet_suffix)"
  type        = string
  default     = "pilot-vnet"
}

variable "vnet_address_space" {
  description = "Spoke VNet 주소 공간"
  type        = list(string)
  default     = ["10.2.0.0/24"]
}

variable "subnets" {
  description = "Spoke 서브넷 구성 (Linux 서버용 서브넷 등)"
  type = map(object({
    address_prefixes                      = list(string)
    service_endpoints                     = optional(list(string), [])
    private_endpoint_network_policies     = optional(string, "Disabled")
    private_link_service_network_policies = optional(string, "Disabled")
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }))
  }))
  default = {
    "pilot-snet" = {
      address_prefixes  = ["10.2.0.0/26"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.EventHub"]
    }
  }
}
```

- 기존 `spoke-vnet`의 `subnets`(apim-snet, pep-snet 등) 대신 Pilot용 `pilot-snet` 하나만 두었습니다. 필요하면 서브넷을 더 추가하면 됩니다.

#### 추가: `azure/dev/01.network/main.tf`

**역할:** Pilot Spoke를 루트에서 모듈로 호출. 기존 `module "spoke_vnet"` 블록 **아래**에 다음 블록을 **추가**합니다.

```hcl
#--------------------------------------------------------------
# Pilot Spoke VNet (신규 VNet)
#--------------------------------------------------------------
module "spoke_vnet_pilot" {
  source = "./spoke-vnet-pilot"

  providers = {
    azurerm     = azurerm.spoke
    azurerm.hub = azurerm.hub
  }

  project_name             = var.project_name
  environment              = var.environment
  location                 = var.location
  tags                     = var.tags
  name_prefix              = local.name_prefix
  hub_vnet_id              = module.hub_vnet.vnet_id
  hub_resource_group_name  = module.hub_vnet.resource_group_name
  private_dns_zone_ids     = local.hub_zone_ids_for_spoke_link
  private_dns_zone_keys    = local.hub_zone_keys_for_spoke
  private_dns_zone_names   = local.hub_zone_names_for_spoke
  spoke_private_dns_zones  = local.spoke_private_dns_zones

  depends_on = [module.hub_vnet]
}
```

#### 추가: `azure/dev/01.network/outputs.tf`

**역할:** Compute 스택에서 Pilot Spoke의 서브넷 ID·RG 이름을 `terraform_remote_state`로 읽을 수 있도록 출력 추가.

파일 **끝**에 아래 블록을 **추가**합니다.

```hcl
# Pilot Spoke VNet Outputs (Compute에서 Linux Pilot VM 배치 시 사용)
output "spoke_pilot_resource_group_name" {
  description = "Pilot Spoke resource group name"
  value       = module.spoke_vnet_pilot.resource_group_name
}

output "spoke_pilot_subnet_ids" {
  description = "Map of Pilot Spoke subnet names to IDs"
  value       = module.spoke_vnet_pilot.subnet_ids
}
```

- Linux 서버를 `pilot-snet`에 둘 경우 Compute에서는 `spoke_pilot_subnet_ids["pilot-snet"]`으로 서브넷 ID를 사용합니다.

### 5.3 방화벽: Hub Key Vault 접근 허용 (keyvault-sg·ASG)

**목표:** Hub의 Key Vault는 Private Endpoint(pep-snet)에 있음. Spoke의 Linux 서버가 Key Vault(443)에 접속하려면  
① 아웃바운드로 Key Vault(443) 허용,  
② PE 쪽 NSG에서 **소스 = keyvault-clients ASG, 포트 443** 인바운드 허용이 필요합니다.  
VM NIC에 `keyvault_clients` ASG를 붙이면 한 정책으로 허용됩니다.

#### 수정: `azure/dev/01.network/terraform.tfvars`

**역할:** keyvault-sg 모듈 및 PE 인바운드(ASG) 활성화. 아래 변수들을 **설정 또는 주석 해제**합니다.

```hcl
# 시나리오 3: keyvault-sg — Key Vault 접근 허용
enable_keyvault_sg = true
# 기존 Hub NSG에 Allow KeyVault 아웃바운드 규칙 추가 (monitoring_vm, pep)
hub_nsg_keys_add_keyvault_rule = ["monitoring_vm", "pep"]
# PE(pep-snet) NSG 인바운드: 소스 = keyvault-clients ASG, 포트 443 → VM NIC에 keyvault_clients ASG 붙이면 접근 허용
enable_pe_inbound_from_asg = true
keyvault_clients_asg_name  = "keyvault-clients-asg"
```

- 이미 `enable_keyvault_sg = true`, `enable_pe_inbound_from_asg = true`로 되어 있으면 변경 없이 유지하면 됩니다.
- Network 스택 `terraform apply` 후 `outputs.tf`의 `keyvault_clients_asg_id`가 채워지며, Compute에서 이 ASG를 VM NIC에 붙입니다.

**복제할 폴더 없음.** 기존 `01.network` 루트의 `terraform.tfvars`만 수정합니다.

### 5.4 새 Linux 서버 (Pilot VM, Spoke 배치)

#### 폴더 복제

```bash
cd azure/dev/06.compute/linux-monitoring-vm
cp -r linux-monitoring-vm linux-pilot-vm
```

- 복제 결과: `azure/dev/06.compute/linux-pilot-vm/` (내부 파일은 기존과 동일)

#### 수정: `azure/dev/06.compute/linux-pilot-vm/variables.tf`

**역할:** 이 VM만의 리소스 정보(이름 접미사, 사이즈, 사용자 등)를 기본값으로 정의. **아래 변수의 기본값만** Pilot용으로 바꿉니다.

| 변수 | 수정 예시 | 설명 |
|------|-----------|------|
| `vm_name_suffix` | `"pilot-vm"` | VM 이름 접미사 (최종: `name_prefix-pilot-vm`) |
| `vm_size` | `"Standard_B2s"` 등 | VM SKU |
| `admin_username` | `"azureadmin"` | 로그인 계정 (필요 시 변경) |
| `ssh_private_key_filename` | `"pilot_vm_key.pem"` | Compute 루트에 저장할 키 파일명 (기존 VM과 구분) |

**예시 코드 (기본값만 변경):**

```hcl
variable "vm_name_suffix" {
  description = "VM 이름 접미사. 최종 이름은 name_prefix-vm_name_suffix"
  type        = string
  default     = "pilot-vm"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "ssh_private_key_filename" {
  description = "SSH 개인키 파일명 (compute 루트에 저장). .gitignore 대상"
  type        = string
  default     = "pilot_vm_key.pem"
}
```

- 나머지 변수(`name_prefix`, `resource_group_name`, `subnet_id`, `application_security_group_ids` 등)는 루트 `main.tf`에서 전달하므로 이 폴더에서는 기본값만 맞추면 됩니다.

#### 수정: `azure/dev/06.compute/main.tf`

**역할:**  
① Network state에서 Pilot Spoke 서브넷·RG 이름을 읽고,  
② `linux-pilot-vm` 모듈을 **Spoke 구독**에 배치하며,  
③ 동일한 방화벽 정책(ASG)을 적용해 Key Vault 접근을 허용합니다.

**추가할 내용:**

1) **locals 블록 안**에 Pilot용 서브넷·RG 참조 추가 (기존 `hub_rg`, `hub_subnet`, `asg_id_by_key` 등 아래):

```hcl
  # Pilot Spoke: Linux Pilot VM 배치용
  spoke_pilot_rg      = try(data.terraform_remote_state.network.outputs.spoke_pilot_resource_group_name, null)
  spoke_pilot_subnet  = try(data.terraform_remote_state.network.outputs.spoke_pilot_subnet_ids["pilot-snet"], null)
```

2) **module 블록** 추가 (예: `module "windows_example"` 아래):

```hcl
#--------------------------------------------------------------
# Linux Pilot VM (Spoke Pilot VNet, Key Vault 접근용 ASG 적용)
#--------------------------------------------------------------
module "linux_pilot_vm" {
  source = "./linux-pilot-vm"

  providers = {
    azurerm = azurerm.spoke
  }

  name_prefix                   = local.name_prefix
  resource_group_name           = local.spoke_pilot_rg
  subnet_id                     = local.spoke_pilot_subnet
  location                      = var.location
  tags                          = var.tags
  application_security_group_ids = local.asg_ids
}
```

- `application_security_group_ids = local.asg_ids`: 루트의 `application_security_group_keys`(기본값 `["keyvault_clients", "vm_allowed_clients"]`)가 Network state의 `keyvault_clients_asg_id` 등으로 해석된 목록입니다. 이걸 그대로 쓰면 Pilot VM NIC에도 Key Vault 접근용 ASG가 붙습니다.
- `spoke_pilot_rg`, `spoke_pilot_subnet`이 `null`이면 Network 스택에 Pilot Spoke 출력이 없다는 뜻이므로, 먼저 01.network apply가 필요합니다.

#### 수정: `azure/dev/06.compute/outputs.tf`

**역할:** RBAC 스택에서 Pilot VM의 Managed Identity를 Key Vault 권한 부여에 사용할 수 있도록 출력 추가.

파일 **끝**에 다음을 **추가**합니다.

```hcl
# Pilot VM (Spoke) — RBAC에서 Hub Key Vault 권한 부여 시 사용
output "pilot_vm_identity_principal_id" {
  description = "Linux Pilot VM Managed Identity principal ID (RBAC Key Vault 역할 부여용)"
  value       = module.linux_pilot_vm.identity_principal_id
}
```

- 필요 시 `linux_pilot_vm_id`, `linux_pilot_vm_name`, `linux_pilot_vm_private_ip` 등도 동일한 방식으로 출력할 수 있습니다.

### 5.5 권한: Hub Key Vault 접근 (RBAC)

**목표:** Hub에 있는 Key Vault(storage 스택에서 생성)에 대해 Pilot VM의 Managed Identity에 **Key Vault Secrets User**, **Key Vault Reader** 역할을 부여합니다.

#### 수정: `azure/dev/08.rbac/main.tf`

**역할:**  
① Compute state에서 Pilot VM의 `principal_id`를 읽고,  
② 해당 principal에 Hub Key Vault scope로 역할 할당 리소스를 추가합니다.

**추가할 내용:**

1) **locals 블록 안**에 Pilot VM principal 참조 추가 (기존 `vm_principal_id` 등 근처):

```hcl
  # Pilot VM (Spoke) Identity — Hub Key Vault 권한 부여용
  pilot_vm_principal_id = try(data.terraform_remote_state.compute.outputs.pilot_vm_identity_principal_id, null)
  enable_pilot_vm_keyvault_roles = var.enable_key_vault_roles && local.pilot_vm_principal_id != null && try(data.terraform_remote_state.storage.outputs.key_vault_id, null) != null
```

2) **역할 할당 리소스** 추가 (기존 `azurerm_role_assignment.vm_key_vault_reader` 블록 **아래**):

```hcl
#--------------------------------------------------------------
# Hub: Pilot VM (Spoke) → Key Vault (Secrets User, Reader)
#--------------------------------------------------------------
resource "azurerm_role_assignment" "pilot_vm_key_vault_access" {
  count = local.enable_pilot_vm_keyvault_roles ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name  = "Key Vault Secrets User"
  principal_id         = local.pilot_vm_principal_id
}

resource "azurerm_role_assignment" "pilot_vm_key_vault_reader" {
  count = local.enable_pilot_vm_keyvault_roles ? 1 : 0

  provider = azurerm.hub

  scope                = data.terraform_remote_state.storage.outputs.key_vault_id
  role_definition_name  = "Key Vault Reader"
  principal_id         = local.pilot_vm_principal_id
}
```

- `enable_key_vault_roles`가 이미 `terraform.tfvars`에서 `true`로 설정되어 있으면, Pilot VM이 배포된 후 RBAC apply 시 위 역할이 부여됩니다.
- **복제할 폴더 없음.** `08.rbac/main.tf`만 수정합니다.

### 5.6 배포 순서 요약

1. **01.network**  
   - `spoke-vnet` → `spoke-vnet-pilot` 복제 후 `spoke-vnet-pilot/variables.tf` 수정  
   - `main.tf`에 `module "spoke_vnet_pilot"` 추가  
   - `outputs.tf`에 `spoke_pilot_resource_group_name`, `spoke_pilot_subnet_ids` 추가  
   - `terraform.tfvars`에서 `enable_keyvault_sg`, `enable_pe_inbound_from_asg` 등 설정  
   - `terraform init -backend-config=backend.hcl && terraform plan -var-file=terraform.tfvars && terraform apply -var-file=terraform.tfvars`

2. **06.compute**  
   - `linux-monitoring-vm` → `linux-pilot-vm` 복제 후 `linux-pilot-vm/variables.tf` 수정  
   - `main.tf`에 `spoke_pilot_*` locals 및 `module "linux_pilot_vm"` 추가  
   - `outputs.tf`에 `pilot_vm_identity_principal_id` 추가  
   - `terraform init -backend-config=backend.hcl && terraform plan -var-file=terraform.tfvars && terraform apply -var-file=terraform.tfvars`

3. **08.rbac**  
   - `main.tf`에 `pilot_vm_principal_id`·`enable_pilot_vm_keyvault_roles` locals 및 Pilot VM용 Key Vault 역할 할당 2개 추가  
   - `terraform init -backend-config=backend.hcl && terraform plan -var-file=terraform.tfvars && terraform apply -var-file=terraform.tfvars`

### 5.7 파일별 체크리스트

| 파일 | 작업 |
|------|------|
| `01.network/spoke-vnet-pilot/variables.tf` | 폴더 복제 후 `rg_suffix`, `vnet_suffix`, `vnet_address_space`, `subnets` 기본값 수정 |
| `01.network/main.tf` | `module "spoke_vnet_pilot" { ... }` 블록 추가 |
| `01.network/outputs.tf` | `spoke_pilot_resource_group_name`, `spoke_pilot_subnet_ids` output 추가 |
| `01.network/terraform.tfvars` | `enable_keyvault_sg`, `hub_nsg_keys_add_keyvault_rule`, `enable_pe_inbound_from_asg` 설정 |
| `06.compute/linux-pilot-vm/variables.tf` | 폴더 복제 후 `vm_name_suffix`, `vm_size`, `admin_username`, `ssh_private_key_filename` 등 기본값 수정 |
| `06.compute/main.tf` | `spoke_pilot_rg`, `spoke_pilot_subnet` locals 및 `module "linux_pilot_vm"` 추가 |
| `06.compute/outputs.tf` | `pilot_vm_identity_principal_id` output 추가 |
| `08.rbac/main.tf` | `pilot_vm_principal_id`, `enable_pilot_vm_keyvault_roles` locals 및 Pilot VM용 Key Vault 역할 할당 2개 추가 |

위 순서대로 복제·수정 후 각 스택을 순서대로 적용하면, 새 Pilot VNet 위의 Linux 서버에서 Hub Key Vault로 방화벽·권한이 모두 적용된 상태로 접속할 수 있습니다.

---

## 6. 참고 링크

- **스택별 상세 가이드**: 각 스택 디렉터리의 `README.md` (예: `azure/dev/01.network/README.md`, `azure/dev/06.compute/README.md`).  
  - 각 스택 README에는 **「0. 복사/붙여넣기용 배포 명령어」** 절이 있어, 명령어 블록을 그대로 복사해 터미널에 붙여넣기만 하면 됩니다.  
  - **변수 관리**: 루트는 컨텍스트(구독·backend·remote_state 출력)만, 리소스 정보(이름·사이즈·옵션)는 **해당 하위 폴더 variables.tf 기본값**에서 관리합니다. 신규 인스턴스 추가 시 **폴더 복사** → **그 폴더 variables.tf만 수정** → **루트 main.tf에 module 블록만 추가**하면 됩니다. (각 스택 README의 「변수 관리 방식」「추가 가이드」 참고.)
- **Backend·backend.hcl 생성**: `bootstrap/backend/README.md`.
- **선배포 아키텍처 동기화(코드 정합화 -> state 동기화 -> Terraform-only 전환) 시나리오**: `ARCHITECTURE_SYNC_SCENARIO_GUIDE.md`.
- **자주 나오는 오류**: 구독 Provider 미등록(409) → [3.1 구독 Resource Provider 등록](#31-구독-resource-provider-필수-등록). OpenAI 쿼터 부족 → [3.3 AI 모델 지정](#33-ai-모델-지정-방법-가이드-ai-services-스택).
