# Terraform IaC (Azure Hub-Spoke 인프라)

이 저장소는 **스택 분리 방식**으로 Azure Hub/Spoke 인프라를 관리합니다.  
각 스택은 **독립 State**를 가지며, **terraform-modules** 레포의 공통 모듈만 참조합니다.

---

## 1. 사용자 환경

배포 및 스크립트 실행에 필요한 환경입니다.

| 구분 | 요구 사항 |
|------|-----------|
| **Terraform** | **1.9 이상** (shared-services 스택의 AVM 기반 모듈 사용). [다운로드](https://www.terraform.io/downloads) |
| **Azure CLI** | 설치 후 `az login`으로 로그인. [설치 가이드](https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli) |
| **Bash** | `scripts/generate-backend-hcl.sh` 실행용. Windows는 Git Bash 또는 WSL 권장. |
| **OS** | Windows, macOS, Linux (Terraform·Azure CLI 지원 환경) |
| **Azure 구독** | Hub 구독 1개, Spoke 구독 1개 (동일 구독으로 Hub/Spoke 구성 가능) |
| **권한** | 각 구독에서 **Contributor** 또는 **Owner** |
| **인증** | `az login` 또는 환경 변수: `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` |

- **Backend 저장소**: Terraform State용 Azure Storage Account·Container는 **Bootstrap** 스택으로 최초 1회 생성합니다.

---

## 2. modules / IaC 레포의 역할·정의·디렉토리 구조

### 2.1 역할과 정의

| 저장소 | 역할 | 정의 |
|--------|------|------|
| **terraform-iac** (이 레포) | **배포용** | `terraform init` / `plan` / `apply`를 실행하는 쪽. 스택별 디렉터리, Backend 설정, `terraform.tfvars`, 배포 순서가 여기 있음. |
| **terraform-modules** ([GitHub](https://github.com/kimchibee/terraform-modules)) | **공통 모듈** | Hub VNet, Spoke VNet, Monitoring Storage, Log Analytics, APIM/OpenAI/AI Foundry 등 **재사용 모듈**만 보관. **apply는 하지 않음.** |

- **참조 방식**: terraform-iac의 각 스택은 `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"` 형태로 **Git 레포만** 참조합니다. 로컬 `modules/` 경로는 사용하지 않습니다.
- **AVM**: azurerm이 필수인 경우가 아니면 **Azure Verified Module(AVM)** 을 사용합니다.
- **모듈 버전 업데이트**: terraform-modules 쪽 코드나 `ref`를 바꾼 경우, 해당 스택에서 `terraform init -upgrade` 후 plan/apply

### 2.2 디렉토리 구조 (terraform-iac)

배포·관리 체계에 맞춘 실제 디렉터리 구조입니다. **plan/apply는 각 스택의 루트에서만** 실행하며, 스택당 State 1개입니다.

```
terraform-iac/
├── azure/dev/                          # 스택별 배포 디렉터리 (각 스택 루트에서 plan/apply, State 키: azure/dev/01.network/terraform.tfstate 등)
│   ├── 01.network/                     # (1) Hub/Spoke VNet, VPN Gateway, DNS Resolver, NSG
│   │   ├── hub-vnet/                   # Hub VNet 하위 모듈
│   │   ├── spoke-vnet/                 # Spoke VNet 하위 모듈 (신규 Spoke 시 폴더 복사 → 해당 폴더 variables.tf만 수정 → 루트에 module만 추가)
│   │   ├── keyvault-sg/                # (옵션) Key Vault 접근 허용 NSG·ASG
│   │   └── vm-access-sg/               # (옵션) VM 접속 허용 ASG·NSG 규칙
│   ├── 02.storage/                     # (2) Key Vault, Monitoring Storage, Private Endpoint
│   │   └── monitoring-storage/         # 하위 모듈 (동일 세트 추가 시 폴더 복사 → 해당 폴더 variables.tf만 수정 → 루트에 module만 추가)
│   ├── 03.shared-services/             # (3) Log Analytics, Solutions, Action Group, Dashboard
│   │   ├── log-analytics-workspace/   # 하위 모듈 (보존 일수 등 폴더 variables.tf 기본값)
│   │   └── shared-services/            # 하위 모듈 (enable 등 폴더 variables.tf 기본값)
│   ├── 04.apim/                         # (4) API Management (Internal VNet). 하위 모듈 없음, 루트에서 Git 모듈 참조
│   ├── 05.ai-services/                  # (5) Azure OpenAI, AI Foundry. 하위 모듈 없음, 루트에서 Git 모듈 참조
│   ├── 06.compute/                      # (6) VM·Managed Identity (스택 루트에서 plan/apply, State 1개)
│   │   ├── linux-monitoring-vm/        # Linux VM 모듈 (신규 VM 시 폴더 복사 → 해당 폴더 variables.tf만 수정 → 루트에 module만 추가)
│   │   └── windows-example/            # Windows VM 모듈 (동일. Windows만 루트에 admin_password 1개 추가)
│   ├── 07.rbac/                         # (7) Monitoring VM 역할 할당 + 그룹 기반 역할·멤버십 관리
│   │   ├── admin-group/                # 관리자 그룹 (역할 부여)
│   │   │   └── admin-users/            # 멤버십 관리: 그룹 소속 사용자·그룹 등록·변경·삭제(Terraform)
│   │   └── ai-developer-group/         # AI 개발자 그룹 (역할 부여). 신규 그룹 시 폴더 복사
│   │       └── ai-developer-users/     # 멤버십 관리: 그룹 소속 사용자·그룹 등록·변경·삭제(Terraform)
│   └── 08.connectivity/                 # (8) VNet Peering, 진단 설정. 하위 모듈 없음
├── bootstrap/backend/                  # Backend용 Storage Account·Container (최초 1회). backend.hcl 사용 안 함
├── scripts/
│   └── generate-backend-hcl.sh         # Bootstrap apply 후 실행 → azure/dev/01.network, 02.storage, ... 각 스택에 backend.hcl 생성
├── config/                             # (선택) 정책·설정 예시 (acr-policy.json, apim-policy.xml, openai-deployments.json)
└── .github/workflows/                  # (선택) CI 워크플로
```

- 각 스택 **루트**에는 `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `provider.tf`, `terraform.tfvars.example` 등이 있습니다. **하위 디렉터리는 모듈**로만 사용(하위에서 backend/remote_state 없음).
- **backend.hcl**은 저장소에 포함되지 않으며, **Bootstrap 적용 후** `./scripts/generate-backend-hcl.sh` 실행으로 각 스택 디렉터리에 생성됩니다.

**변수 관리 방식 (스택 공통)**  
- **루트**: 구독 ID, backend, location, tags, remote_state로 얻는 컨텍스트(리소스 그룹명·서브넷 ID 등)만 관리.  
- **하위 폴더**: 각 리소스의 **이름·사이즈·옵션**(주소 공간, 서브넷, 보존 일수, 역할 이름 등)은 **해당 폴더의 variables.tf 기본값**에서 관리.  
→ 신규 인스턴스 추가 시: **폴더 복사** → **복사한 폴더의 variables.tf 기본값만 수정** → **루트 main.tf에 module 블록만 추가**. 루트 `variables.tf`·`terraform.tfvars`에 인스턴스별 변수를 추가하지 않음. (예: compute의 VM, network의 Spoke, storage의 monitoring-storage, shared-services의 log-analytics, rbac의 그룹.)

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
| **ai-services** | Spoke | Azure OpenAI, AI Foundry(ML Workspace), 관련 Private Endpoint·Private DNS Zone |
| **compute** | Hub | Linux VM(Monitoring), Windows VM(예시), Managed Identity |
| **rbac** | Hub/Spoke | Role Assignment (Monitoring VM, 그룹 역할) + 그룹 멤버십 등록·변경·삭제(Terraform) |
| **connectivity** | Hub | VNet Peering(Hub↔Spoke), VPN Connection, 진단 설정 |

- 상세 리소스 이름·서브넷 목록은 각 스택 디렉터리의 `README.md`(예: `azure/dev/01.network/README.md`, `azure/dev/06.compute/README.md`)를 참고하세요.

### 2.4 스택별 azurerm / AVM 참조

- **azurerm (루트/로컬에서 직접)**: 해당 스택의 루트 또는 로컬 모듈에서 `resource "azurerm_*"` / `data "azurerm_*"`를 직접 사용하는지 여부.
- **AVM (모듈)**: AVM을 통해 모듈을 사용하는지. 데이터 저장·모듈화 등으로 azurerm을 함께 쓰는 경우도 있음.

| 스택 | azurerm (루트/로컬에서 직접) | AVM (모듈) | 비고 |
|------|:---------------------------:|:----------:|------|
| **network** | ✅ keyvault-sg (NSG, ASG, rule 등) | ✅ | 공동모듈(hub-vnet, spoke-vnet) 호출 + 로컬 keyvault-sg에서 NSG·ASG 등 azurerm 직접 사용. |
| **storage** | — | ✅ | |
| **shared-services** | — | ✅ | |
| **apim** | — | ✅ | |
| **ai-services** | — | ✅ | |
| **compute** | — | ✅ | |
| **rbac** | ✅ main.tf, ai-developer-group (role_assignment) | — | 루트 main.tf 및 ai-developer-group에서 azurerm_role_assignment만 사용. |
| **connectivity** | — | ✅ | |

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
| - | **backend.hcl 생성** | 프로젝트 루트 | — | Bootstrap **apply 완료 후** `./scripts/generate-backend-hcl.sh` 실행. |
| 1 | network | `azure/dev/01.network` | **Hub:** `test-x-x-rg`, `test-x-x-vnet`, 서브넷(GatewaySubnet, DNSResolver-Inbound, AzureFirewallSubnet, AzureFirewallManagementSubnet, AppGatewaySubnet, Monitoring-VM-Subnet, pep-snet), `test-x-x-vpng`, `test-x-x-vpng-pip`, `test-x-x-pdr`, Private DNS Zone(14종), `test-monitoring-vm-nsg`, `test-pep-nsg`, (옵션) `test-x-x-keyvault-sg`, `test-x-x-vm-allowed-clients-asg`. **Spoke:** `test-x-x-spoke-rg`, `test-x-x-spoke-vnet`, 서브넷(apim-snet, pep-snet), `test-spoke-pep-nsg`, Private DNS Zone(5종), VNet Link | Hub/Spoke VNet, VPN Gateway, DNS Resolver, NSG |
| 2 | storage | `azure/dev/02.storage` | Key Vault `test-hub-kv`, Monitoring Storage Account(apimlog, vpnglog, vnetlog, nsglog, aoailog, aifoundrylog, acrlog, spkvlog 등), Key Vault·Storage용 Private Endpoint | Key Vault, Monitoring Storage, PE |
| 3 | shared-services | `azure/dev/03.shared-services` | Log Analytics Workspace `test-x-x-law`, Solutions, Action Group, Dashboard | Log Analytics, Solutions, Action Group, Dashboard |
| 4 | apim | `azure/dev/04.apim` | API Management(이름은 tfvars/변수 기준), APIM·관련 Private Endpoint, Private DNS Zone 링크 | API Management |
| 5 | ai-services | `azure/dev/05.ai-services` | Azure OpenAI 리소스, Azure AI Foundry(ML Workspace), OpenAI·ML·Notebooks·Storage 등 Private Endpoint, Private DNS Zone | Azure OpenAI, AI Foundry (모델은 3.3 참고) |
| 6 | compute | `azure/dev/06.compute` | Linux VM `test-x-x-monitoring-vm`, Windows VM `test-x-x-win-example`, 각 VM의 Managed Identity, NIC, OS Disk | Linux/Windows VM. VM 추가 시 폴더 복사 후 루트에 module·변수 추가 |
| 7 | rbac | `azure/dev/07.rbac` | Role Assignment(Monitoring VM → Storage Blob Data Contributor, Key Vault Secrets User 등), (옵션) admin-group/ai-developer-group 그룹 역할·멤버십 | Monitoring VM 역할 할당, 그룹 기반 권한 |
| 8 | connectivity | `azure/dev/08.connectivity` | VNet Peering `test-x-x-vnet-to-spoke`, `test-x-x-spoke-vnet-to-hub`, 진단 설정(`test-x-x-vnet-vpng-storage-diag`, `test-x-x-vnet-storage-diag`, NSG 진단 등) | VNet Peering, 진단 설정 |

**각 스택 공통 절차:**

```bash
cd azure/dev/01.network   # 또는 02.storage, 03.shared-services, ... 08.connectivity
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 (구독 ID, backend 관련 변수 등)
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **backend.hcl**은 `./scripts/generate-backend-hcl.sh` 실행으로 생성됩니다. 수동 작성 방법은 **Bootstrap 스택 README** (`bootstrap/backend/README.md`)를 참고하세요.
- **삭제(롤백) 시**: 스택을 제거할 때는 **배포의 역순**으로 진행하는 것이 안전합니다. **08.connectivity → 07.rbac → 06.compute → 05.ai-services → 04.apim → 03.shared-services → 02.storage → 01.network**. 각 스택 **루트** 디렉터리에서 `terraform destroy -var-file=terraform.tfvars` 실행.

### 3.3 AI 모델 지정 방법 가이드 (ai-services 스택)

- **Azure OpenAI 모델 배포**는 리전별 **쿼터**가 필요합니다. 쿼터 없으면 `InsufficientQuota` 오류가 발생합니다.
- **쿼터 승인 전**: `azure/dev/05.ai-services/terraform.tfvars`에서 `openai_deployments = []` 로 두고 배포하면 **모델 배포 없이** AI Foundry, Private Endpoints 등만 생성됩니다.
- **쿼터 승인 후** 모델을 배포하려면:

1. **쿼터 확인**  
   `az cognitiveservices usage list --location koreacentral -o table`  
   쿼터 요청: [https://aka.ms/oai/stuquotarequest](https://aka.ms/oai/stuquotarequest)

2. **변수 수정**  
   `azure/dev/05.ai-services/terraform.tfvars`에서:
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

- 예시와 상세 옵션은 `azure/dev/05.ai-services/terraform.tfvars.example` 및 `docs/AZURE-OPENAI-QUOTA-AND-MODELS.md`(있는 경우)를 참고하세요.

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

## 참고 링크

- **스택별 상세 가이드**: 각 스택 디렉터리의 `README.md` (예: `azure/dev/01.network/README.md`, `azure/dev/06.compute/README.md`).  
  - 각 스택 README에는 **「0. 복사/붙여넣기용 배포 명령어」** 절이 있어, 명령어 블록을 그대로 복사해 터미널에 붙여넣기만 하면 됩니다.  
  - **변수 관리**: 루트는 컨텍스트(구독·backend·remote_state 출력)만, 리소스 정보(이름·사이즈·옵션)는 **해당 하위 폴더 variables.tf 기본값**에서 관리합니다. 신규 인스턴스 추가 시 **폴더 복사** → **그 폴더 variables.tf만 수정** → **루트 main.tf에 module 블록만 추가**하면 됩니다. (각 스택 README의 「변수 관리 방식」「추가 가이드」 참고.)
- **Backend·backend.hcl 생성**: `bootstrap/backend/README.md`.
- **자주 나오는 오류**: 구독 Provider 미등록(409) → [3.1 구독 Resource Provider 등록](#31-구독-resource-provider-필수-등록). OpenAI 쿼터 부족 → [3.3 AI 모델 지정](#33-ai-모델-지정-방법-가이드-ai-services-스택).
