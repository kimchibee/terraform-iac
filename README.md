# Terraform IaC (Azure 인프라 배포)

이 저장소는 **AWS 스택 분리 방식**을 적용하여 Azure Hub/Spoke 인프라를 관리합니다.  
각 스택을 **독립적으로 배포/롤백**할 수 있으며, **State 파일이 분리**되어 있습니다.

---

## 처음 Terraform을 사용하는 사람을 위한 메뉴얼

Terraform을 처음 쓰는 경우, 아래 순서대로 읽으면 **기초 개념 → 배포 → 검증 → 리소스 추가/변경/삭제**까지 한 번에 이해할 수 있습니다.

### Terraform 기초 (필수 명령어)

| 명령어 | 설명 |
|--------|------|
| **terraform init** | 프로바이더·모듈 다운로드, Backend(State 저장 위치) 초기화. 스택 디렉터리 진입 후 **최초 1회** 또는 backend 설정 변경 시 실행. |
| **terraform plan** | 코드와 현재 State를 비교해 **무엇이 추가/변경/삭제될지** 미리 보여 줌. 실제 리소스는 변경되지 않음. |
| **terraform apply** | plan에서 제안한 변경을 **실제 Azure에 반영**. 확인 프롬프트가 나오면 `yes` 입력. |
| **terraform destroy** | 해당 스택에서 관리 중인 리소스를 **전부 삭제**. 신중히 사용. |

- **State**: Terraform이 "지금 관리 중인 리소스 목록"을 저장한 파일. 보통 Azure Storage에 원격 저장되어 팀이 공유함.
- **스택**: `azure/dev/` 아래 한 디렉터리(예: network, storage)가 한 스택. 스택마다 **별도 State**를 가지므로, 한 스택만 배포·롤백 가능.

### 스택 순서대로 배포하는 방법

배포는 **반드시 아래 순서**를 지켜야 합니다. 뒤쪽 스택이 앞쪽 스택의 출력(remote_state)을 참조하기 때문입니다.

| 순서 | 스택 | 디렉터리 | 한 줄 요약 |
|------|------|----------|------------|
| 0 | Bootstrap | `bootstrap/backend` | Backend용 Storage 계정·컨테이너 생성 (최초 1회) |
| 1 | network | `azure/dev/network` | Hub/Spoke VNet, 서브넷, VPN Gateway, DNS Resolver, NSG |
| 2 | storage | `azure/dev/storage` | Key Vault, Monitoring Storage 계정들, Private Endpoints |
| 3 | shared-services | `azure/dev/shared-services` | Log Analytics, Solutions, Action Group, Dashboard |
| 4 | apim | `azure/dev/apim` | API Management |
| 5 | ai-services | `azure/dev/ai-services` | Azure OpenAI, AI Foundry, ACR, Private Endpoints |
| 6 | compute | `azure/dev/compute` | Monitoring VM, Role Assignments |
| 7 | connectivity | `azure/dev/connectivity` | VNet Peering (Hub↔Spoke), 진단 설정 |

**각 스택 공통 절차:**

1. 해당 디렉터리로 이동: `cd azure/dev/<스택명>`
2. 변수 파일 준비: `cp terraform.tfvars.example terraform.tfvars` 후 구독 ID 등 수정
3. Backend 설정: `backend.hcl.example`을 복사해 `backend.hcl`로 만들고, Bootstrap에서 나온 `resource_group_name`, `storage_account_name`, `container_name` 입력
4. 초기화 및 적용:
   ```bash
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
5. apply 시 "Do you want to perform these actions?" 나오면 **yes** 입력

상세한 단계별 명령어는 아래 [빠른 시작](#빠른-시작)과 [배포 단계](#배포-단계)를 참고하세요.

### 배포 검증: Azure에서 리소스가 정상인지 확인

배포 후 **az 명령어**로 실제 Azure에 리소스가 생겼는지 확인할 수 있습니다. (구독 ID는 본인 환경에 맞게 바꿔서 실행.)

```bash
az account set --subscription "YOUR_SUBSCRIPTION_ID"
az group list --query "[?contains(name,'test-x-x') || contains(name,'terraform-state')].{name:name, location:location}" -o table
az resource list --resource-group "test-x-x-rg" --query "[].{name:name, type:type}" -o table
az resource list --resource-group "test-x-x-spoke-rg" --query "[].{name:name, type:type}" -o table
az network vnet peering list --resource-group "test-x-x-rg" --vnet-name "test-x-x-vnet" -o table
```

**검증 결과 요약 (실제 조회 기준):**

| 항목 | 기대 결과 |
|------|-----------|
| 리소스 그룹 | `terraform-state-rg`, `test-x-x-rg`, `test-x-x-spoke-rg` (koreacentral) |
| Hub VNet | `test-x-x-vnet` (10.0.0.0/20) |
| Spoke VNet | `test-x-x-spoke-vnet` (10.1.0.0/24) |
| Peering | `test-x-x-vnet-to-spoke` → **Connected** |
| Hub 리소스 | VNet, VPN Gateway, NSG, Key Vault, Storage 11개, VM, Log Analytics, Solutions 등 |
| Spoke 리소스 | APIM, Azure OpenAI, AI Foundry, ACR, Storage, Private Endpoints 3개 등 |

위 명령에서 에러 없이 리소스가 나오고, Peering이 Connected이면 **모든 스택이 정상 배포된 것**으로 볼 수 있습니다.

### 리소스 추가 방법

- **기존 스택에 리소스 추가**: 해당 스택의 `main.tf`에 모듈 또는 리소스 블록을 추가하고, `variables.tf`·`terraform.tfvars`에 변수와 값을 넣은 뒤, 해당 디렉터리에서 `terraform plan` → `terraform apply` 실행.
- **예: VM 추가**  
  `azure/dev/compute/main.tf`에 새 VM 모듈 블록 추가 → `variables.tf`에 변수 정의 → `terraform.tfvars`에 값 설정 → `cd azure/dev/compute` 후 `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`.
- **예: Storage 계정 추가**  
  Storage 스택의 `main.tf`에 `azurerm_storage_account` 리소스 또는 모듈 호출 추가 후 동일하게 plan/apply.

자세한 예시(새 VM, 새 Storage, 새 APIM 등)는 아래 [새 인스턴스 생성 방법](#새-인스턴스-생성-방법)을 참고하세요.

### 리소스 변경 방법

1. 해당 스택의 **코드**(`.tf`) 또는 **변수**(`terraform.tfvars`)를 수정합니다.
2. 해당 스택 디렉터리에서 `terraform plan -var-file=terraform.tfvars`로 변경 계획을 확인합니다.
3. 문제 없으면 `terraform apply -var-file=terraform.tfvars`로 적용합니다.

Terraform은 **선언형**이므로, "원하는 최종 상태"를 코드에 쓰면 Terraform이 현재 상태와 비교해 필요한 변경만 수행합니다.

### 리소스 삭제 방법

- **특정 리소스만 삭제**:  
  `terraform destroy -target=리소스_주소 -var-file=terraform.tfvars`  
  예: `terraform destroy -target=module.monitoring_vm[0] -var-file=terraform.tfvars`
- **해당 스택 전체 삭제**:  
  해당 스택 디렉터리에서 `terraform destroy -var-file=terraform.tfvars`  
  (확인 프롬프트에 `yes` 입력)
- **리소스만 Azure에서 삭제하고 State에는 남기고 싶지 않다면**:  
  보통은 `destroy`로 State와 실제 리소스를 함께 제거하는 것이 맞습니다. 이미 Azure에서 수동 삭제한 리소스는 `terraform state rm <주소>`로 State에서만 제거할 수 있습니다.

스택 삭제는 **의존성 역순**(connectivity → compute → ai-services → apim → shared-services → storage → network)으로 진행하는 것이 안전합니다.

### Backend Storage(State 저장소) 이름 수정

State를 저장하는 **스토리지 계정 이름**은 Azure **전역 고유**이므로, 레포를 clone한 사용자는 본인만의 이름으로 바꿔야 합니다.

1. `bootstrap/backend/terraform.tfvars`에서 **storage_account_name**을 소문자·숫자만 3~24자(하이픈 불가)로 수정. 예: `tfstate` + 구독 ID 뒤 6자리.
2. Bootstrap을 먼저 실행해 해당 이름으로 Storage 계정을 생성한 뒤, 각 스택의 `backend.hcl`에 동일한 `storage_account_name`을 넣습니다.

### 공동 모듈(terraform-modules) 수정이 필요할 때

모든 스택은 공통 모듈을 **terraform-modules** 레포(Git)만 참조합니다. 모듈 쪽 코드를 바꿔야 할 때:

1. **terraform-modules** 레포를 로컬에서 수정한 뒤, 원격에 커밋·푸시합니다.
2. **terraform-iac**의 해당 스택에서 `terraform init -upgrade`(또는 `terraform get -update`)로 모듈을 다시 받습니다.
3. `terraform plan` / `terraform apply`로 동작을 확인합니다.

모듈의 **ref**(브랜치/태그)를 바꾸려면 해당 스택의 `main.tf` 등에서 `source = "git::...?ref=main"`의 `ref`만 변경한 뒤 init/plan/apply 하면 됩니다.

---

## 사용자 환경 (필요한 것)

이 코드를 사용하려면 아래 환경을 갖춰야 합니다.

| 구분 | 내용 |
|------|------|
| **OS** | Windows, macOS, Linux (Terraform·Azure CLI 지원 환경) |
| **Terraform** | **1.9 이상** (shared-services 스택의 공통 모듈이 1.9+ 필요). [다운로드](https://www.terraform.io/downloads) |
| **Azure CLI** | 설치 후 `az login`으로 로그인. [설치 가이드](https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli) |
| **Azure 구독** | Hub 구독 1개, Spoke 구독 1개 (또는 단일 구독으로 Hub/Spoke 동시 구성 가능) |
| **권한** | 각 구독에서 **Contributor** 또는 **Owner** (리소스 생성·State 저장소 접근 필요) |
| **Backend 저장소** | Terraform State를 저장할 Azure Storage Account·Container. 최초 1회 **bootstrap**으로 생성. |
| **환경 변수 (선택)** | `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET` 등으로 서비스 주체 인증 가능. 미설정 시 `az login` 계정 사용. |

### 구독 Resource Provider 등록 (필수)

각 스택에서 사용하는 Azure 서비스를 쓰려면 **구독에 해당 Resource Provider가 등록**되어 있어야 합니다. 등록되지 않으면 `MissingSubscriptionRegistration`(409) 오류가 발생합니다. 배포 전에 아래 Provider를 등록하세요.

| Provider | 사용 스택 | 용도 |
|----------|-----------|------|
| `Microsoft.OperationalInsights` | shared-services | Log Analytics Workspace |
| `Microsoft.Insights` | shared-services | Action Group, Monitor 리소스 |
| `Microsoft.OperationsManagement` | shared-services | Log Analytics Solutions (ContainerInsights, SecurityInsights) |
| `Microsoft.ApiManagement` | apim | API Management 서비스 |
| `Microsoft.Network` | network, connectivity | VNet, Subnet, NSG, VPN Gateway, Peering 등 (대부분 구독에 기본 등록됨) |
| `Microsoft.Storage` | bootstrap, storage | Storage Account |
| `Microsoft.KeyVault` | storage | Key Vault |
| `Microsoft.Compute` | compute | VM 등 |

**등록 명령 (Azure CLI):**

```bash
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.ApiManagement
# 필요 시 추가
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Compute
```

**등록 완료 확인:** `az provider show --namespace <Namespace> --query "registrationState" -o tsv` → `Registered`가 나올 때까지 대기 후 배포 진행.

---

**정리:** PC에 Terraform 1.9+ 와 Azure CLI를 설치하고, `az login` 한 뒤, **위 Resource Provider를 구독에 등록**하고, 배포할 구독 ID를 각 스택의 `terraform.tfvars`에 넣으면 됩니다.

---

## 이 저장소는 어떻게 구성되어 있는가

- **두 저장소 역할**
  - **terraform-iac (이 저장소)**: 실제로 `terraform init / plan / apply`를 실행하는 **배포용** 저장소. 스택별 디렉터리, Backend 설정, 변수 파일이 여기 있음.
  - **[terraform-modules](https://github.com/kimchibee/terraform-modules) (GitHub)**: 재사용 가능한 **공통 모듈**만 모음. terraform-iac의 각 스택이 **반드시 GitHub**의 해당 레포만 `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"` 형태로 참조함. **terraform-modules에서는 apply 하지 않음.**

- **불변 규칙 (절대 변경 금지)**
  1. **공동 모듈 소스**: 모든 공통 모듈은 **modules GitHub**만 바라보도록 지정. GitLab/로컬 경로로 바꾸지 않음.
  2. **AVM 사용**: azurerm이 필수적으로 필요한 케이스가 아닌 경우 **Azure Verified Module(AVM)** 을 사용함.

- **스택이란**  
  `azure/dev/` 아래 **network**, **storage**, **shared-services**, **apim**, **ai-services**, **compute**, **connectivity** 처럼 **한 디렉터리 = 한 스택**입니다. 스택마다 별도 State 파일을 쓰므로, 한 스택만 배포·롤백할 수 있습니다.

- **배포 순서**  
  **1 → 2 → 3 → … → 7** 순서를 지켜야 합니다. (network → storage → shared-services → apim → ai-services → compute → connectivity)  
  뒤쪽 스택이 앞쪽 스택의 **출력(remote_state)**을 참조하기 때문입니다.

- **한 블록씩 실행하는 배포 명령어**  
  리소스 전부 삭제 후 처음부터 배포하거나, 단계별로 복사해 실행하려면 위 [스택 순서대로 배포하는 방법](#스택-순서대로-배포하는-방법)과 아래 [빠른 시작](#빠른-시작)·[배포 단계](#배포-단계)를 참고하세요. (Bootstrap → backend.hcl → 스택 1~7)

- **설정 파일**  
  각 스택 디렉터리에는 `terraform.tfvars.example`이 있습니다. 복사해 `terraform.tfvars`로 만든 뒤, 구독 ID·리소스 이름 등만 채우면 됩니다.

- **ai-services 스택: Azure OpenAI 모델 배포**  
  Azure OpenAI **모델 배포**는 리전별 쿼터가 필요합니다. 쿼터 승인 전에는 **모델 관련 배포가 비활성화**되어 있으며(`openai_deployments = []`), **승인 후 재시도 시** `azure/dev/ai-services/terraform.tfvars`에서 해당 블록 주석을 해제하고 모델을 설정해야 합니다. 자세한 내용은 아래 [ai-services 스택: Azure OpenAI 쿼터 안내](#ai-services-스택-azure-openai-쿼터-안내) 및 [모델 없이 ai-services 배포](#모델-없이-ai-services-배포)를 참고하세요.

- **레포 다운받은 후 필수 수정: Backend Storage 이름**  
  Terraform state를 저장하는 **스토리지 계정 이름(storage_account_name)** 은 **Azure 전역 고유** 리소스입니다. 다른 사용자와 겹치면 생성이 실패하므로, `bootstrap/backend/terraform.tfvars`에서 **본인만의 고유명**(소문자·숫자 3~24자, 하이픈 불가)으로 반드시 수정하세요.  
  → 상세: 위 [Backend Storage(State 저장소) 이름 수정](#backend-storagestate-저장소-이름-수정).

- **공동 모듈 참조**  
  **모든 스택**은 공통 모듈을 **terraform-modules 레포(Git)**만 참조합니다. 로컬 `modules/` 경로는 사용하지 않습니다.  
  → **공동 모듈 수정이 필요할 때**: 위 [공동 모듈(terraform-modules) 수정이 필요할 때](#공동-모듈terraform-modules-수정이-필요할-때) 참고.

---

## 전체 디렉터리 구조

```
terraform-iac/
├── azure/                          # 스택 분리 방식 (AWS 방식 적용)
│   └── dev/
│       ├── network/                # 스택 1: Hub/Spoke VNet
│       ├── storage/                # 스택 2: Key Vault, Storage Accounts
│       ├── shared-services/        # 스택 3: Log Analytics, Shared Services
│       ├── apim/                   # 스택 4: API Management
│       ├── ai-services/            # 스택 5: Azure OpenAI, AI Foundry
│       ├── compute/                # 스택 6: Monitoring VM, Role Assignments
│       └── connectivity/           # 스택 7: VNet Peering, Diagnostic Settings
├── bootstrap/                      # Backend 초기 설정
│   └── backend/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/                        # IaC 전용 모듈 (스택에서 공통 사용)
│   └── dev/
│       ├── hub/
│       │   ├── vnet/
│       │   ├── monitoring-storage/
│       │   └── shared-services/
│       └── spoke/
│           └── vnet/
└── config/                         # 정책·설정 파일
    ├── acr-policy.json
    ├── apim-policy.xml
    └── openai-deployments.json
```

---

## 전체 아키텍처 개요

### Hub-Spoke 네트워크 아키텍처

이 인프라는 **Azure Hub-Spoke 네트워크 아키텍처**를 기반으로 구성되어 있습니다.

```
┌─────────────────────────────────────────────────────────────┐
│                    Hub Subscription                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Hub VNet (중앙 허브)                                 │   │
│  │  ├── VPN Gateway (온프레미스 연결)                    │   │
│  │  ├── DNS Private Resolver                             │   │
│  │  ├── Private DNS Zones                                │   │
│  │  ├── Key Vault                                        │   │
│  │  ├── Monitoring VM                                    │   │
│  │  └── Monitoring Storage Accounts                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Shared Services                                      │   │
│  │  ├── Log Analytics Workspace                         │   │
│  │  └── Security Insights                                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ VNet Peering
                          │
┌─────────────────────────┴─────────────────────────────────┐
│                  Spoke Subscription                       │
│  ┌──────────────────────────────────────────────────────┐ │
│  │  Spoke VNet (워크로드)                                │ │
│  │  ├── API Management (Private)                         │ │
│  │  ├── Azure OpenAI                                    │ │
│  │  ├── AI Foundry                                     │ │
│  │  └── Private Endpoints                               │ │
│  └──────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────┘
```

### 스택별 역할 및 책임

| 스택 | 포함 리소스 | 의존성 | 실행 순서 |
|------|------------|--------|----------|
| **network** | hub_vnet, spoke_vnet, VPN Gateway, DNS Resolver, Private DNS Zones, NSG | 없음 | 1 (최초) |
| **storage** | Key Vault, Monitoring Storage Accounts, Private Endpoints | network (remote_state) | 2 |
| **shared-services** | Log Analytics Workspace, Shared Services (Solutions, Action Group, Dashboard) | network (remote_state) | 3 |
| **apim** | API Management | network, shared-services (remote_state) | 4 |
| **ai-services** | Azure OpenAI, AI Foundry | network, storage, shared-services (remote_state) | 5 |
| **compute** | Monitoring VM, Role Assignments (VM → Storage/Key Vault/Spoke Resources) | network, storage, ai-services (remote_state) | 6 |
| **connectivity** | VNet Peering, Diagnostic Settings | network, storage, shared-services (remote_state) | 7 |

### ai-services 스택: Azure OpenAI 쿼터 안내

- **Azure OpenAI 모델 배포**는 구독·리전별 **쿼터**가 할당되어 있어야 생성할 수 있습니다. 쿼터가 없으면 `InsufficientQuota` 오류가 발생합니다.
- **승인 시점이 불명확한 경우**를 위해, 현재는 **모델 관련 배포만 비활성화**해 두었습니다.  
  - `azure/dev/ai-services/terraform.tfvars` 에서 `openai_deployments = []` 로 두고, 모델 블록은 주석 처리되어 있습니다.
  - **쿼터 승인 후 재시도** 시에는 **반드시 아래를 수정**해야 합니다:  
    1) `openai_deployments = []` 를 제거하고  
    2) 주석 처리된 모델 블록을 해제한 뒤, 사용할 모델(`name`, `model_name`, `version`, `capacity`)로 설정  
  - 쿼터 확인: `az cognitiveservices usage list --location koreacentral -o table`  
  - 쿼터 요청: [https://aka.ms/oai/stuquotarequest](https://aka.ms/oai/stuquotarequest)

### 모델 없이 ai-services 배포

모델 배포 없이 **AI Foundry, Private Endpoints 등 나머지 리소스만** 먼저 배포하려면:

1. **변수 확인**  
   `azure/dev/ai-services/terraform.tfvars` 에서 `openai_deployments = []` 인지 확인합니다. (이미 비활성화되어 있으면 수정 불필요)

2. **ai-services 스택 적용**  
   ```bash
   cd azure/dev/ai-services
   terraform init -backend-config=backend.hcl
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
   이렇게 하면 Azure OpenAI **모델 배포**는 생성되지 않고, 스택에 정의된 그 외 리소스(AI Foundry, ACR, Private Endpoints, 진단 설정 등)만 배포됩니다.

3. **나중에 쿼터 승인 후**  
   위 [쿼터 안내](#ai-services-스택-azure-openai-쿼터-안내)대로 `terraform.tfvars` 에서 모델 블록을 활성화한 뒤, 다시 `terraform plan` / `terraform apply` 를 실행하면 모델 배포가 추가됩니다.

---

## 빠른 시작

### 필수 사전 준비

1. **도구 설치**
   - **Terraform 1.9+** 설치 (shared-services 스택이 terraform-modules AVM 래퍼 사용 시 1.9 이상 필요)
   - Azure CLI 설치 및 로그인: `az login`
   - Hub/Spoke 구독 ID 확보

2. **Azure 권한 확인**
   - Hub 구독: `Contributor` 또는 `Owner` 권한
   - Spoke 구독: `Contributor` 또는 `Owner` 권한

### 배포 단계

#### 1. Bootstrap (Backend 초기 설정)

**최초 1회만 실행** - Backend Storage Account와 Container를 생성합니다.

```bash
cd bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정 (resource_group_name, storage_account_name 등)
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- Resource Group: `terraform-state-rg` (또는 지정한 이름)
- Storage Account: `terraformstate` (또는 지정한 이름, 전역 고유)
- Container: `tfstate`
- Private Endpoint (선택사항)

**출력 확인:**
```bash
terraform output
# resource_group_name, storage_account_name, container_name 확인
```

#### 2. Network 스택 (최초 배포)

```bash
cd ../../azure/dev/network
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정 (구독 ID, 네트워크 설정 등)

# Backend 설정 파일 생성
cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/network/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- Hub VNet, Subnets, VPN Gateway, DNS Resolver, Private DNS Zones, NSG
- Spoke VNet, Subnets

**주의사항:**
- Spoke VNet은 초기 배포 시 `hub_key_vault_id`, `log_analytics_workspace_id` 등을 빈 값으로 설정
- Storage와 Shared Services 스택 배포 후 Network 스택을 다시 실행하여 업데이트 가능

#### 3. Storage 스택

```bash
cd ../storage
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/storage/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- Key Vault
- Monitoring Storage Accounts (vpnglog, vnetlog, nsglog 등)
- Private Endpoints for Storage Accounts

#### 4. Shared Services 스택

```bash
cd ../shared-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/shared-services/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- Log Analytics Workspace
- Shared Services (Solutions, Action Group, Dashboard)

#### 5. APIM 스택

```bash
cd ../apim
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/apim/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- API Management (Internal VNet mode)

#### 6. AI Services 스택

> **참고:** 쿼터 승인 전에는 `terraform.tfvars` / `terraform.tfvars.example` 에서 **모델 배포가 비활성화**되어 있습니다(`openai_deployments = []`). 이 상태로 apply 하면 **모델을 제외한 리소스**(AI Foundry, Private Endpoints 등)만 배포됩니다. 쿼터 승인 후 [위 안내](#ai-services-스택-azure-openai-쿼터-안내)대로 모델 블록을 활성화한 뒤 다시 apply 하면 됩니다.

```bash
cd ../ai-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정 (openai_deployments = [] 이면 모델 없이 배포)

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/ai-services/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스 (모델 비활성화 시):**
- AI Foundry (Azure Machine Learning Workspace), Private Endpoints, 진단 설정 등 (Azure OpenAI **모델 배포** 제외)

**쿼터 승인 후 모델 활성화 시 추가 생성:**
- Azure OpenAI Cognitive Service 및 모델 배포(gpt-4o-mini 등)

#### 7. Compute 스택

```bash
cd ../compute
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정 (vm_admin_password 등)

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/compute/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- Monitoring VM
- Role Assignments (VM → Storage Accounts, Key Vault, Spoke Resources)

**Storage 스택 업데이트:**
- Compute 스택 배포 후, Storage 스택을 다시 실행하여 VM Identity를 Storage Accounts에 연결

```bash
cd ../storage
terraform apply -var-file=terraform.tfvars
```

#### 8. Connectivity 스택

```bash
cd ../connectivity
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정

cat > backend.hcl <<EOF
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/connectivity/terraform.tfstate"
EOF

terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**생성 리소스:**
- VNet Peering (Hub ↔ Spoke)
- Diagnostic Settings (VPN Gateway, VNet, NSG)

---

## 스택 배포 및 롤백

### 스택 배포

#### 전체 스택 순차 배포

```bash
# 1. Bootstrap
cd bootstrap/backend && terraform apply

# 2. Network
cd ../../azure/dev/network && terraform apply

# 3. Storage
cd ../storage && terraform apply

# 4. Shared Services
cd ../shared-services && terraform apply

# 5. APIM
cd ../apim && terraform apply

# 6. AI Services
cd ../ai-services && terraform apply

# 7. Compute
cd ../compute && terraform apply

# 8. Connectivity
cd ../connectivity && terraform apply
```

#### 특정 스택만 배포

```bash
# 예: Storage 스택만 배포
cd azure/dev/storage
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### 스택 롤백

#### 특정 스택만 롤백

```bash
# 예: Compute 스택 롤백
cd azure/dev/compute

# 1. 이전 State로 롤백 (State 파일이 버전 관리되는 경우)
terraform state pull > current.tfstate
# 이전 버전의 State 파일로 교체

# 2. 또는 특정 리소스만 제거
terraform destroy -target=module.monitoring_vm -var-file=terraform.tfvars
```

#### State 파일 백업 및 복원

```bash
# State 파일 백업
az storage blob download \
  --account-name terraformstate \
  --container-name tfstate \
  --name azure/dev/compute/terraform.tfstate \
  --file compute.tfstate.backup

# State 파일 복원
az storage blob upload \
  --account-name terraformstate \
  --container-name tfstate \
  --name azure/dev/compute/terraform.tfstate \
  --file compute.tfstate.backup \
  --overwrite
```

---

## 새 인스턴스 생성 방법

### 새 Linux VM 생성

#### 방법 1: Compute 스택에 직접 추가

**1) `azure/dev/compute/main.tf`에 새 VM 모듈 추가**

```hcl
#--------------------------------------------------------------
# New Linux VM Instance
#--------------------------------------------------------------
module "app_server_vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"
  count  = var.enable_app_server_vm ? 1 : 0

  providers = {
    azurerm = azurerm.hub
  }

  name                = local.app_server_vm_name
  os_type             = "linux"
  size                = var.app_server_vm_size
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_id           = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]  # 또는 다른 서브넷
  admin_username      = var.app_server_vm_admin_username
  admin_password      = var.app_server_vm_admin_password
  tags                = var.tags
  enable_identity      = true
}
```

**2) `azure/dev/compute/locals.tf`에 VM 이름 추가**

```hcl
locals {
  name_prefix = "${var.project_name}-x-x"
  hub_vm_name = "${local.name_prefix}-vm"
  app_server_vm_name = "${local.name_prefix}-app-vm"  # 추가
}
```

**3) `azure/dev/compute/variables.tf`에 변수 추가**

```hcl
variable "enable_app_server_vm" {
  description = "Enable App Server VM deployment"
  type        = bool
  default     = false
}

variable "app_server_vm_size" {
  description = "Size of the app server VM"
  type        = string
  default     = "Standard_B2s"
}

variable "app_server_vm_admin_username" {
  description = "Admin username for app server VM"
  type        = string
  default     = "azureadmin"
}

variable "app_server_vm_admin_password" {
  description = "Admin password for app server VM"
  type        = string
  sensitive   = true
  default     = ""
}
```

**4) `azure/dev/compute/terraform.tfvars`에 값 설정**

```hcl
enable_app_server_vm = true
app_server_vm_size = "Standard_B2s"
app_server_vm_admin_username = "azureadmin"
app_server_vm_admin_password = "YourSecurePassword123!"
```

**5) 배포**

```bash
cd azure/dev/compute
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

#### 방법 2: 새 스택 생성 (대규모 워크로드)

**새 워크로드 스택 생성 예시:**

```bash
mkdir -p azure/dev/workload
cd azure/dev/workload
```

**`main.tf` 생성:**

```hcl
#--------------------------------------------------------------
# Workload Stack
# 애플리케이션 서버 VM들을 관리하는 스택
#--------------------------------------------------------------

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/network/terraform.tfstate"
  }
}

module "app_server_vm" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/virtual-machine?ref=main"

  providers = {
    azurerm = azurerm.hub
  }

  name                = "${var.project_name}-x-x-app-vm"
  os_type             = "linux"
  size                = var.vm_size
  location            = var.location
  resource_group_name = data.terraform_remote_state.network.outputs.hub_resource_group_name
  subnet_id           = data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password
  tags                = var.tags
  enable_identity      = true
}
```

**나머지 파일들도 생성** (`variables.tf`, `outputs.tf`, `provider.tf`, `backend.tf`, `terraform.tfvars.example`)

### 새 Storage Account 생성

**Storage 스택에 추가:**

**1) `azure/dev/storage/main.tf` 수정**

```hcl
# 기존 storage 모듈은 그대로 두고, 추가 Storage Account 리소스 생성
resource "azurerm_storage_account" "additional" {
  name                          = "${var.project_name}add${random_string.storage_suffix.result}"
  resource_group_name           = data.terraform_remote_state.network.outputs.hub_resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = var.tags
}
```

### 새 API Management 인스턴스 생성

**APIM 스택은 하나의 APIM만 관리하므로, 새 APIM이 필요하면:**

1. **새 스택 생성**: `azure/dev/apim-prod/` (환경별 분리)
2. **또는 기존 APIM 스택에 추가**: `azure/dev/apim/main.tf`에 추가 APIM 리소스 정의

---

## State 관리

### State 파일 위치

각 스택의 State 파일은 Backend Storage Account에 저장됩니다:

```
azure/dev/network/terraform.tfstate
azure/dev/storage/terraform.tfstate
azure/dev/shared-services/terraform.tfstate
azure/dev/apim/terraform.tfstate
azure/dev/ai-services/terraform.tfstate
azure/dev/compute/terraform.tfstate
azure/dev/connectivity/terraform.tfstate
```

### State 파일 확인

```bash
# 특정 스택의 State 확인
cd azure/dev/network
terraform state list

# State 출력 확인
terraform output
```

### State 파일 백업

```bash
# 모든 스택 State 백업
for stack in network storage shared-services apim ai-services compute connectivity; do
  cd azure/dev/$stack
  terraform state pull > ../../backups/${stack}.tfstate.backup
done
```

---

## terraform-modules 연동 스택 검증

**shared-services** 스택은 공동 모듈(terraform-modules)의 **log-analytics-workspace**(AVM 래퍼)를 사용합니다. 배포 전 아래로 검증하세요.

1. **Terraform 버전**: `terraform version` → **1.9 이상** 필요.
2. **shared-services init/validate**:
   ```bash
   cd azure/dev/shared-services
   terraform init -backend=false   # 또는 실제 backend 설정 후 init
   terraform validate
   ```
3. **각 스택 검증**은 아래 "스택별 init/validate 명령" 표를 순서대로 실행하면 됩니다.
4. 자세한 요구사항·이슈 대응은 **terraform-modules** 레포의 `README.md` 참고.

---

### 스택별 init/validate 명령 (한 스택씩 검증 시)

아래는 스택 순서대로 한 줄씩 실행하면 됩니다. 경로는 프로젝트 루트 기준입니다.

| 순서 | 스택 | 명령 |
|------|------|------|
| 1 | network | `cd azure/dev/network` → `terraform init -upgrade -backend=false` → `terraform validate` |
| 2 | storage | `cd azure/dev/storage` → `terraform init -backend=false` → `terraform validate` |
| 3 | shared-services | `cd azure/dev/shared-services` → `terraform init -backend=false` → `terraform validate` |
| 4 | apim | `cd azure/dev/apim` → `terraform init -backend=false` → `terraform validate` |
| 5 | ai-services | `cd azure/dev/ai-services` → `terraform init -backend=false` → `terraform validate` |
| 6 | compute | `cd azure/dev/compute` → `terraform init -backend=false` → `terraform validate` |
| 7 | connectivity | `cd azure/dev/connectivity` → `terraform init -backend=false` → `terraform validate` |

---

## 문제 해결

### 문제 1: `terraform_remote_state`에서 데이터를 읽을 수 없음

```bash
# 해결: 이전 스택이 배포되었는지 확인
cd azure/dev/network
terraform output

# State 파일이 올바른 위치에 있는지 확인
az storage blob list \
  --account-name terraformstate \
  --container-name tfstate \
  --output table
```

### 문제 2: Backend 초기화 실패

```bash
# 해결: Backend 설정 파일 확인
cat backend.hcl

# Backend 리소스가 생성되었는지 확인
az storage account show --name terraformstate --resource-group terraform-state-rg
```

### 문제 3: 순환 의존성 오류

```bash
# 해결: 스택 배포 순서 확인
# Network → Storage → Shared Services → APIM → AI Services → Compute → Connectivity
```

### 문제 4: 특정 스택만 롤백

```bash
# 예: Compute 스택만 destroy
cd azure/dev/compute
terraform destroy -var-file=terraform.tfvars

# 특정 리소스만 제거
terraform destroy -target=module.monitoring_vm -var-file=terraform.tfvars
```

---

## 배포된 인프라 정보

### 전체 리소스 통계

| 항목 | 배포된 인프라 | Terraform 구조 | 일치 여부 |
|------|-------------|---------------|----------|
| 총 리소스 그룹 | 2개 | 2개 | ✅ |
| 총 Virtual Networks | 2개 | 2개 | ✅ |
| 총 서브넷 | 10개 | 10개 | ✅ |
| 총 Private DNS Zones | 13개 | 13개 | ✅ |
| 총 Storage Accounts | 13개 | 13개 | ✅ |
| 총 Private Endpoints | 17개 | 17개 | ✅ |
| 총 Key Vaults | 3개 | 3개 | ✅ |
| 총 Virtual Machines | 1개 | 1개 | ✅ |

### Hub 리소스 그룹 (`test-x-x-rg`)

| 리소스 타입 | 배포됨 | Terraform | 일치 여부 |
|------------|--------|-----------|----------|
| Virtual Networks | 1 | ✅ | ✅ |
| Subnets | 8 | ✅ | ✅ |
| VPN Gateway | 1 | ✅ | ✅ |
| DNS Resolver | 1 | ✅ | ✅ |
| Private DNS Zones | 13 | ✅ | ✅ |
| NSG | 2 | ✅ | ✅ |
| Log Analytics Workspace | 1 | ✅ | ✅ |
| Solutions | 2 | ✅ | ✅ |
| Action Group | 1 | ✅ | ✅ |
| Dashboard | 1 | ✅ | ✅ |
| Key Vault | 1 | ✅ | ✅ |
| Storage Accounts | 11 | ✅ | ✅ |
| Private Endpoints | 12 | ✅ | ✅ |
| Virtual Machine | 1 | ✅ | ✅ |
| Network Interface | 1 | ✅ | ✅ |
| VM Extensions | 2 | ✅ | ✅ |
| VNet Peering | 1 | ✅ | ✅ |
| Role Assignments | 4 | ✅ | ✅ |

**총 리소스 수**: 약 111개 (배포됨) = 약 111개 (Terraform) ✅

### Spoke 리소스 그룹 (`test-x-x-spoke-rg`)

| 리소스 타입 | 배포됨 | Terraform | 일치 여부 |
|------------|--------|-----------|----------|
| Virtual Networks | 1 | ✅ | ✅ |
| Subnets | 2 | ✅ | ✅ |
| NSG | 2 | ✅ | ✅ |
| API Management | 1 | ✅ | ✅ |
| Azure OpenAI | 1 | ✅ | ✅ |
| AI Foundry Workspace | 1 | ✅ | ✅ |
| Storage Accounts | 2 | ✅ | ✅ |
| Container Registries | 2 | ✅ | ✅ |
| Key Vaults | 2 | ✅ | ✅ |
| Application Insights | 2 | ✅ | ✅ |
| Private Endpoints | 5 | ✅ | ✅ |
| VNet Peering | 1 | ✅ | ✅ |
| Role Assignments | 5 | ✅ | ✅ |

**총 리소스 수**: 약 24개 (배포됨) = 약 24개 (Terraform) ✅

### 주요 특징

#### 1. 스택 분리 구조
- 각 스택이 독립적으로 배포/롤백 가능
- State 파일 분리로 충돌 최소화
- 책임 분리 명확

#### 2. 중앙 집중식 모니터링
- 모든 리소스의 로그가 Hub의 중앙 Storage Account로 수집
- Log Analytics Workspace를 통한 통합 분석
- Monitoring VM을 통한 중앙 집중식 로그 수집

#### 3. Private Endpoint 전략
- 모든 주요 서비스는 Private Endpoint를 통해 접근
- Public 인터넷 노출 최소화
- 네트워크 격리 및 보안 강화

#### 4. Hub-Spoke 아키텍처
- Hub: 중앙 집중식 네트워크 및 보안 서비스
- Spoke: 워크로드 실행 환경
- VNet Peering을 통한 안전한 연결

#### 5. 보안 강화
- NSG를 통한 네트워크 트래픽 제어
- Managed Identity를 통한 서비스 간 인증
- Role-Based Access Control (RBAC) 적용

---

## 모듈 구조

### IaC 전용 모듈

`modules/dev/` 디렉터리에 환경별 모듈이 있습니다:

- `modules/dev/hub/vnet/` - Hub VNet 모듈
- `modules/dev/hub/monitoring-storage/` - Storage 모듈
- `modules/dev/hub/shared-services/` - Shared Services 모듈
- `modules/dev/spoke/vnet/` - Spoke VNet 모듈

### 공통 모듈

공통 모듈은 **[terraform-modules](https://github.com/kimchibee/terraform-modules)** 레포에서 관리됩니다:

- `log-analytics-workspace` - Log Analytics Workspace
- `virtual-machine` - Linux/Windows VM
- `vnet-peering` - VNet Peering

**사용 방법:**
```hcl
source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"
```

---

## AWS 방식과의 비교

| 항목 | AWS IaC (terraform-infra) | Azure IaC (현재 프로젝트) |
|------|---------------------------|---------------------------|
| **구조** | 스택별 완전 분리 (각 디렉터리에서 독립 실행) | ✅ 동일 (스택별 완전 분리) |
| **State 관리** | 스택별 State 파일 (`terraform_remote_state` 사용) | ✅ 동일 (스택별 State 파일) |
| **의존성 관리** | `terraform_remote_state`로 이전 스택 State 읽기 | ✅ 동일 (`terraform_remote_state` 사용) |
| **모듈 구조** | 공통 모듈만 사용 (Git 레포) | 공통 모듈 + IaC 전용 모듈 혼용 |
| **실행 방식** | 각 스택 디렉터리에서 개별 실행 | ✅ 동일 (각 스택 디렉터리에서 개별 실행) |
| **확장성** | 환경/도메인 추가 시 디렉터리 복사 | ✅ 동일 (환경 추가 시 디렉터리 복사) |

---

**마지막 업데이트**: 2026-01-23  
**환경**: dev  
**위치**: Korea Central  
**Terraform 버전**: ~> 1.5
