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

```
terraform-iac/
├── azure/dev/                    # 스택별 배포 디렉터리 (각각 별도 State)
│   ├── network/                  # Hub/Spoke VNet, VPN Gateway, DNS Resolver, NSG
│   ├── storage/                  # Key Vault, Monitoring Storage, Private Endpoints
│   ├── shared-services/          # Log Analytics, Solutions, Action Group, Dashboard
│   ├── apim/                     # API Management
│   ├── ai-services/               # Azure OpenAI, AI Foundry
│   ├── compute/                  # Monitoring VM
│   ├── rbac/                     # Monitoring VM → Hub/Spoke 역할 할당
│   └── connectivity/             # VNet Peering (Hub↔Spoke), 진단 설정
├── bootstrap/backend/            # Backend용 Storage Account·Container (최초 1회)
├── scripts/
│   └── generate-backend-hcl.sh   # Bootstrap 적용 후 각 스택에 backend.hcl 생성
└── config/                       # (선택) 정책·설정 파일
```

- 각 스택 디렉터리에는 `main.tf`, `variables.tf`, `terraform.tfvars.example`, `backend.tf` 등이 있으며, `backend.hcl`은 **Bootstrap 적용 후 스크립트로 생성**합니다.

---

## 3. 초기 배포 작업 순서

전체 흐름: **Bootstrap → backend.hcl 생성 스크립트 실행 → 각 스택을 순서대로 배포**합니다.

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

### 3.2 배포 순서 요약

| 순서 | 스택 | 디렉터리 | 비고 |
|------|------|----------|------|
| 0 | Bootstrap | `bootstrap/backend` | Backend Storage·Container 생성. **최초 1회.** `terraform init`만 사용(backend.hcl 없음). |
| - | **backend.hcl 생성** | 프로젝트 루트 | Bootstrap **apply 완료 후** `./scripts/generate-backend-hcl.sh` 실행. |
| 1 | network | `azure/dev/network` | Hub/Spoke VNet, 서브넷, VPN Gateway, DNS Resolver, NSG |
| 2 | storage | `azure/dev/storage` | Key Vault, Monitoring Storage, PE |
| 3 | shared-services | `azure/dev/shared-services` | Log Analytics, Solutions, Action Group, Dashboard |
| 4 | apim | `azure/dev/apim` | API Management |
| 5 | ai-services | `azure/dev/ai-services` | Azure OpenAI, AI Foundry (모델은 3.3 참고) |
| 6 | compute | `azure/dev/compute` | Monitoring VM |
| 7 | rbac | `azure/dev/rbac` | Monitoring VM 역할 할당 |
| 8 | connectivity | `azure/dev/connectivity` | VNet Peering, 진단 설정 |

**각 스택 공통 절차:**

```bash
cd azure/dev/<스택명>
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집 (구독 ID, backend 관련 변수 등)
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **backend.hcl**은 `./scripts/generate-backend-hcl.sh` 실행으로 생성됩니다. 수동 작성 방법은 **Bootstrap 스택 README** (`bootstrap/backend/README.md`)를 참고하세요.
- **삭제(롤백) 시**: 스택을 제거할 때는 **배포의 역순**으로 진행하는 것이 안전 connectivity → rbac → compute → ai-services → apim → shared-services → storage → network. 각 스택 디렉터리에서 `terraform destroy -var-file=terraform.tfvars` 실행.

### 3.3 AI 모델 지정 방법 가이드 (ai-services 스택)

- **Azure OpenAI 모델 배포**는 리전별 **쿼터**가 필요합니다. 쿼터 없으면 `InsufficientQuota` 오류가 발생합니다.
- **쿼터 승인 전**: `azure/dev/ai-services/terraform.tfvars`에서 `openai_deployments = []` 로 두고 배포하면 **모델 배포 없이** AI Foundry, Private Endpoints 등만 생성됩니다.
- **쿼터 승인 후** 모델을 배포하려면:

1. **쿼터 확인**  
   `az cognitiveservices usage list --location koreacentral -o table`  
   쿼터 요청: [https://aka.ms/oai/stuquotarequest](https://aka.ms/oai/stuquotarequest)

2. **변수 수정**  
   `azure/dev/ai-services/terraform.tfvars`에서:
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
   `cd azure/dev/ai-services` 후 `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`

- 예시와 상세 옵션은 `azure/dev/ai-services/terraform.tfvars.example` 및 `docs/AZURE-OPENAI-QUOTA-AND-MODELS.md`(있는 경우)를 참고하세요.

---

## 4. 배포 완료 후 전체 아키텍처 구조

배포가 끝나면 아래와 같은 Hub-Spoke 구조가 만들어집니다.

- **Hub 구독** (`test-x-x-rg`): Hub VNet, VPN Gateway(Site-to-Site), DNS Private Resolver, Key Vault, Monitoring Storage(진단 로그용), Monitoring VM, Log Analytics, Shared Services(Solutions, Action Group, Dashboard).  
  **Spoke 구독** (`test-x-x-spoke-rg`): Spoke VNet, API Management, Azure OpenAI, Azure AI Foundry, 각 서비스용 Private Endpoint 및 Private DNS Zone.
- **연결**: VNet Peering (Hub ↔ Spoke), Spoke 쪽 Private DNS Zone 링크는 Hub에서 생성한 Zone을 사용.

개요만 보면:

```
┌─────────────────────────────────────────────────────────────┐
│                    Hub Subscription (test-x-x-rg)           │
│  Hub VNet ─ VPN Gateway, DNS Resolver, Key Vault,           │
│             Monitoring Storage, Monitoring VM, Log Analytics │
└─────────────────────────────────────────────────────────────┘
                          │ VNet Peering
┌─────────────────────────┴─────────────────────────────────┐
│                  Spoke Subscription (test-x-x-spoke-rg)     │
│  Spoke VNet ─ API Management, Azure OpenAI, AI Foundry, PE  │
└─────────────────────────────────────────────────────────────┘
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

- **스택별 상세 가이드**: 각 스택 디렉터리의 `README.md` (예: `azure/dev/network/README.md`).
- **Backend·backend.hcl 생성**: `bootstrap/backend/README.md`.
- **자주 나오는 오류**: 구독 Provider 미등록(409) → [3.1 구독 Resource Provider 등록](#31-구독-resource-provider-필수-등록). OpenAI 쿼터 부족 → [3.3 AI 모델 지정](#33-ai-모델-지정-방법-가이드-ai-services-스택).
