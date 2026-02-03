# Terraform IaC (Azure 인프라 배포)

이 저장소는 **IaC 레포**이며, **루트 모듈**이 여기서 관리됩니다.  
Azure Hub/Spoke 인프라를 Terraform으로 배포할 때 `terraform plan` / `terraform apply`는 **이 레포 루트**에서 실행합니다.

---

## 이 레포에서 관리하는 것 (루트 모듈)

| 구분 | 내용 |
|------|------|
| **루트 모듈** | `main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `terraform.tf`, `locals.tf`, `data.tf` — 배포 진입점. **이 레포 루트에 있음.** |
| **IaC 전용 모듈** | `modules/` — **환경별**(예: `dev/`) 하위에 **Hub**(vnet, shared-services, monitoring-storage) / **Spoke**(vnet) 기준, 이 프로젝트 전용. |
| **공통 모듈** | **[terraform-modules](https://github.com/kimchibee/terraform-modules)** 레포에서 관리. 이 레포(terraform-iac)에는 포함하지 않으며, `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"` 또는 `?ref=태그` 로만 참조. |

다른 Azure 프로젝트가 생기면 **새 IaC(새 레포 또는 `environments/` 하위)** 를 만들고, **같은 공통 모듈(terraform-modules) 레포**를 참조해 같이 쓸 수 있습니다. → [공통 모듈 관리](#7-공통-모듈-관리) 섹션 참고.

---

## 빠른 시작

### 필수 사전 준비

1. **도구 설치**  
   - Terraform 1.5+ 설치
   - Azure CLI 설치 및 로그인: `az login`
   - Hub/Spoke 구독 ID 확보

2. **Azure 권한 확인**  
   - Hub 구독: `Contributor` 또는 `Owner` 권한
   - Spoke 구독: `Contributor` 또는 `Owner` 권한

### 배포 단계

1. **저장소 클론**  
   ```bash
   git clone https://github.com/kimchibee/terraform-iac.git
   cd terraform-iac
   ```

2. **변수 파일 생성 및 필수 값 설정**  
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   
   **`terraform.tfvars` 파일에서 반드시 수정해야 할 필수 항목:**
   
   | 항목 | 설명 | 예시 |
   |------|------|------|
   | `hub_subscription_id` | Hub 구독 ID | `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` |
   | `spoke_subscription_id` | Spoke 구독 ID | `"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"` |
   | `location` | Azure 리전 | `"Korea Central"` 또는 `"East US"` |
   | `project_name` | 프로젝트 이름 | `"myproject"` |
   | `environment` | 환경 이름 | `"dev"`, `"prod"` 등 |
   | `vm_admin_password` | Monitoring VM 비밀번호 | **강력한 비밀번호** (최소 12자, 대소문자/숫자/특수문자 포함) |
   
   **VPN Gateway 사용 시 추가 필수 항목:**
   - `vpn_shared_key`: VPN 공유 키
   - `local_gateway_configs`: 온프레미스 게이트웨이 IP 및 주소 공간
   
   **API Management 사용 시 추가 필수 항목:**
   - `apim_publisher_name`: 발행자 이름
   - `apim_publisher_email`: 발행자 이메일
   
   ⚠️ **주의**: `terraform.tfvars`는 `.gitignore` 대상이므로 Git에 커밋하지 마세요.

3. **Backend(State) 설정 (선택사항)**  
   원격 State 사용 시 `terraform.tf` 파일에서 다음 블록의 주석을 해제하고 값을 수정:
   ```hcl
   backend "azurerm" {
     resource_group_name  = "terraform-state-rg"      # State 저장소 리소스 그룹
     storage_account_name = "terraformstate"          # State 저장소 계정명
     container_name       = "tfstate"                 # 컨테이너명
     key                  = "terraform.tfstate"      # State 파일 키 (환경별로 분리 가능)
   }
   ```
   
   **Backend를 설정하지 않으면** 로컬에 `terraform.tfstate` 파일이 생성됩니다 (팀 협업 시 권장하지 않음).

4. **초기화 및 배포**  
   ```bash
   # Terraform 초기화 (공통 모듈은 terraform-modules 레포에서 자동 다운로드)
   terraform init
   
   # 배포 계획 확인 (필수 - 변경사항을 먼저 확인)
   terraform plan -var-file=terraform.tfvars
   
   # 배포 실행
   terraform apply -var-file=terraform.tfvars
   ```
   
   **환경별 tfvars 파일 사용 시:**
   ```bash
   terraform plan -var-file=prod.tfvars
   terraform apply -var-file=prod.tfvars
   ```

### 배포 전 체크리스트

배포를 시작하기 전에 다음 항목을 확인하세요:

- [ ] Terraform 1.5+ 설치 확인 (`terraform version`)
- [ ] Azure CLI 로그인 확인 (`az account show`)
- [ ] Hub/Spoke 구독 ID 확인 및 권한 확인
- [ ] `terraform.tfvars` 파일 생성 및 필수 값 설정 완료
  - [ ] `hub_subscription_id` 설정
  - [ ] `spoke_subscription_id` 설정
  - [ ] `location` 설정
  - [ ] `project_name`, `environment` 설정
  - [ ] `vm_admin_password` 설정 (강력한 비밀번호)
- [ ] VPN Gateway 사용 시: `vpn_shared_key`, `local_gateway_configs` 설정
- [ ] API Management 사용 시: `apim_publisher_name`, `apim_publisher_email` 설정
- [ ] Backend 설정 (선택사항이지만 팀 협업 시 권장)

### 예상 배포 시간

- **전체 인프라 배포**: 약 30-60분 (리소스 종류와 개수에 따라 다름)
- **주요 리소스**:
  - Hub VNet: 약 5-10분
  - VPN Gateway: 약 20-30분 (가장 오래 걸림)
  - Spoke VNet 및 워크로드: 약 10-20분

### 문제 해결

배포 중 오류가 발생하면:
1. `terraform plan` 출력 확인
2. Azure Portal에서 리소스 생성 상태 확인
3. [작업 절차](#10-작업-절차) 섹션의 "문제 해결" 참고

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

### 모듈 의존성 관계

```
Hub VNet (최초 생성)
    │
    ├──→ Shared Services (Log Analytics 등)
    │
    ├──→ Storage (Key Vault, Monitoring Storage)
    │
    ├──→ Monitoring VM
    │
    └──→ Spoke VNet (VNet Peering)
            │
            └──→ Role Assignments (Hub VM → Spoke Resources)
```

### 주요 구성 요소

#### Hub VNet
- **역할**: 중앙 집중식 네트워크 허브
- **리소스**: VPN Gateway, DNS Resolver, Private DNS Zones, Key Vault
- **서브넷**: GatewaySubnet, DNSResolver-Inbound/Outbound, Monitoring-VM-Subnet, pep-snet 등

#### Spoke VNet
- **역할**: 워크로드 실행 환경
- **리소스**: API Management, Azure OpenAI, AI Foundry
- **서브넷**: apim-snet, pep-snet

#### Shared Services
- **역할**: 공유 모니터링 및 보안 서비스
- **리소스**: Log Analytics Workspace, Security Insights

#### Storage
- **역할**: 중앙 집중식 스토리지 및 비밀 관리
- **리소스**: Key Vault, Monitoring Storage Accounts

#### Compute
- **역할**: 가상 머신 관리
- **리소스**: Monitoring VM, Linux/Windows VM 인스턴스

---

## 공통 모듈 참조는 어디에 있나?

**공통 모듈(terraform-modules) 참조는 `main.tf`에만 있습니다.**

- **공통 모듈 저장소 주소**: **`https://github.com/kimchibee/terraform-modules.git`**
- **파일**: **`main.tf`** (루트)
- **위치**:
  - **명시 위치**: `main.tf` **맨 위 주석 블록** — "공통 모듈 저장소 지정" 으로 검색하면 됨.
  - **실제 사용 위치**: 각 `module "..."` 블록 안의 **`source = "..."`** 인자 (공통 모듈을 쓸 때)
- **IaC 모듈**: `source = "./modules/환경/경로/모듈명"` (예: `./modules/dev/hub/vnet`, `./modules/dev/spoke/vnet`)
- **공통 모듈(terraform-modules 레포)**: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"` (태그 배포 후에는 `?ref=v1.0.0` 등 사용 가능)

즉, **모듈을 추가·변경·삭제할 때 수정하는 파일은 `main.tf`** 이고,  
공통 모듈 버전을 바꿀 때는 `main.tf`의 해당 `module` 블록에서 `source`의 `ref=` 값만 바꾸면 됩니다.  
**각 환경에 맞추어 수정할 때**는 아래 [각 환경에 맞추어 수정 필요 항목](#6-각-환경에-맞추어-수정-필요-항목) 에서 공통 모듈 저장소 URL 등 수정 대상을 확인하세요.

---

## 파일 및 디렉터리 계층 구조

```
terraform-iac/                       # 이 레포 루트 (IaC 배포 루트)
├── .gitignore
├── .terraform.lock.hcl
├── config/                          # 정책·설정 파일
│   ├── acr-policy.json
│   ├── apim-policy.xml
│   └── openai-deployments.json
├── docs/
│   ├── COMMON_MODULE_MIGRATION.md   # 공통 모듈 vs IaC 분리, 루트 모듈·공통 모듈 공유
│   ├── ROOT_TF_FILES.md             # 루트 .tf 역할·관리·배포 흐름
│   └── HASHICORP_RECOMMENDED_PRACTICES.md  # HashiCorp 권장 사항
├── main.tf                          # 모듈 호출 및 루트 리소스 (Hub/Spoke/Storage/공통 모듈)
├── variables.tf                      # 루트 변수
├── outputs.tf                       # 루트 출력
├── locals.tf                        # 로컬 값 (네이밍 등)
├── data.tf                          # Data 소스
├── provider.tf                      # Azure Provider 설정
├── terraform.tf                     # Backend, required_providers
├── terraform.tfvars.example         # 변수 예시 (실제 값은 tfvars)
│
├── modules/                         # IaC 전용 모듈 (환경별 → Hub / Spoke 기준)
│   └── dev/                         # 개발 환경 (운영계 추가 시 prod/ 등 동일 구성)
│       ├── hub/                     # Hub 네트워크·공유 서비스
│       │   ├── vnet/                # Hub VNet (RG, VNet, Subnet, VPN, DNS Resolver, NSG, Private DNS 등)
│       │   │   ├── main.tf, variables.tf, outputs.tf
│       │   │   ├── diagnostic-settings.tf, dns-resolver.tf, private-dns-zones.tf, vpn-gateway.tf
│       │   ├── shared-services/    # Solutions / Action Group / Dashboard
│       │   │   ├── main.tf, variables.tf, outputs.tf
│       │   └── monitoring-storage/ # Hub 모니터링 스토리지 + Key Vault + PE
│       │       ├── main.tf, keyvault.tf, data.tf, locals.tf, variables.tf, outputs.tf
│       │       └── config/
│       │           └── key-vault-policy.json.example
│       └── spoke/                   # Spoke 네트워크·워크로드
│           └── vnet/                # Spoke VNet (RG, VNet, APIM, OpenAI, AI Foundry, Peering 등)
│               ├── main.tf, variables.tf, outputs.tf
│               ├── ai-foundry.tf, apim.tf, openai.tf, vnet-peering.tf
│
└── terraform_iac/
    └── README.md                    # IaC 루트 안내 (공통 모듈 참조 방법 등)
```

- **루트 `.tf`**: `main.tf`에서 **공통 모듈**은 `git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/...` 로, **IaC 모듈**은 `./modules/...` 로 참조.
- **공통 모듈**: [terraform-modules](https://github.com/kimchibee/terraform-modules) 레포에서 관리 (log-analytics-workspace, virtual-machine, vnet-peering 등). 이 레포에는 포함하지 않으며 `?ref=main` 또는 `?ref=태그` 로 버전 지정.
- **IaC 모듈**: `modules/` — **환경별**(예: `dev/`) 하위에 **Hub**(`dev/hub/vnet`, `dev/hub/shared-services`, `dev/hub/monitoring-storage`) / **Spoke**(`dev/spoke/vnet`) 기준으로 구분, 루트에서만 호출.

---

## 목차

1. [파일별 역할 (어디를 고치면 되는지)](#1-파일별-역할-어디를-고치면-되는지)
2. [리소스 추가 (복사·붙여넣기용)](#2-리소스-추가-복사붙여넣기용)
3. [리소스 변경 (복사·붙여넣기용)](#3-리소스-변경-복사붙여넣기용)
4. [리소스 삭제 (복사·붙여넣기용)](#4-리소스-삭제-복사붙여넣기용)
5. [실행 순서 및 주의사항](#5-실행-순서-및-주의사항)
6. [각 환경에 맞추어 수정 필요 항목](#6-각-환경에-맞추어-수정-필요-항목)
7. [공통 모듈 관리](#7-공통-모듈-관리)
8. [루트 파일 관리](#8-루트-파일-관리)
9. [HashiCorp 권장 사항](#9-hashicorp-권장-사항)
10. [작업 절차](#10-작업-절차)
11. [배포된 인프라 정보](#11-배포된-인프라-정보)

---

## 1. 파일별 역할 (어디를 고치면 되는지)

| 수정 목적 | 파일 | 설명 |
|-----------|------|------|
| **모듈 호출·루트 리소스 추가/삭제** | **`main.tf`** | `module "xxx" { ... }`, `resource "azurerm_xxx" "yyy" { ... }` 여기만 추가/삭제. **공통 모듈 참조(source=git::...)도 여기.** |
| **새 변수 정의** | **`variables.tf`** | `variable "새변수" { ... }` 추가 |
| **변수에 넣을 값** | **`terraform.tfvars`** (또는 `dev.tfvars` 등) | `새변수 = "값"` 형태로 값 지정 (git에 올리지 말 것) |
| **이름·접두사 등 계산 값** | **`locals.tf`** | `locals { 새이름 = "..." }` 추가 |
| **외부로 내보낼 값** | **`outputs.tf`** | `output "xxx" { value = module.xxx.yyy }` 추가 |
| **Provider/구독** | **`provider.tf`** | subscription_id, alias 등 |
| **Backend/버전** | **`terraform.tf`** | backend, required_providers |

---

## 2. 리소스 추가 (복사·붙여넣기용)

아래는 **그대로 복사한 뒤, 주석에 적힌 대로 이름·값만 바꾸면** 사용할 수 있는 예시입니다.

### 2.1 공통 모듈로 Resource Group 추가

**1) `main.tf` 맨 아래에 아래 블록 추가** (모듈 이름·로컬 이름만 본인 환경에 맞게 수정)

```hcl
#--------------------------------------------------------------
# Resource Group (공통 모듈)
#--------------------------------------------------------------
module "새_resource_group" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/resource-group?ref=v1.0.0"

  name     = local.새_rg_name      # locals.tf에 정의
  location = var.location
  tags     = var.tags
}
```

**2) `locals.tf`의 `locals { ... }` 안에 한 줄 추가**

```hcl
새_rg_name = "${local.name_prefix}-새이름-rg"   # 예: "${local.name_prefix}-logging-rg"
```

**3) `terraform init` 후 `terraform plan -var-file=terraform.tfvars`** 로 생성 대상 확인 후 apply.

---

### 2.2 공통 모듈로 VNet 추가

**1) `main.tf`에 추가** (이미 RG가 있어야 함. 없으면 위 2.1 먼저)

```hcl
#--------------------------------------------------------------
# VNet (공통 모듈)
#--------------------------------------------------------------
module "새_vnet" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = module.새_resource_group.name   # 또는 기존 RG 이름
  vnet_name            = local.새_vnet_name
  vnet_address_space   = ["10.1.0.0/16"]                  # 원하는 CIDR
  subnets = {
    "subnet1" = {
      address_prefixes = ["10.1.1.0/24"]
    }
    "subnet2" = {
      address_prefixes = ["10.1.2.0/24"]
    }
  }
  tags = var.tags
}
```

**2) `locals.tf`에 추가**

```hcl
새_vnet_name = "${local.name_prefix}-새이름-vnet"
```

**3) `terraform init -upgrade` (git 모듈 최초 사용 시) → `terraform plan -var-file=terraform.tfvars`**

---

### 2.3 공통 모듈로 Storage Account 추가

**1) `main.tf`에 추가**

```hcl
#--------------------------------------------------------------
# Storage Account (공통 모듈)
#--------------------------------------------------------------
module "새_storage" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/storage-account?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = module.hub_vnet.resource_group_name   # 또는 사용할 RG
  name_prefix          = "mylog"                              # 이름 접두사 (소문자, 3~24자 제한)
  account_tier         = "Standard"
  account_replication_type = "LRS"
  min_tls_version      = "TLS1_2"
  public_network_access_enabled = false
  network_rules = {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [module.hub_vnet.subnet_ids["pep-snet"]]   # PE용 서브넷
    ip_rules                   = []
  }
  tags = var.tags
}
```

**2) 필요 시 `outputs.tf`에 추가**

```hcl
output "새_storage_id" {
  value = module.새_storage.storage_account_id
}
```

---

### 2.4 공통 모듈로 Key Vault 추가

**1) `main.tf`에 추가**

```hcl
#--------------------------------------------------------------
# Key Vault (공통 모듈)
#--------------------------------------------------------------
module "새_key_vault" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/key-vault?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  name                 = local.새_kv_name    # 3~24자, 영숫자·하이픈, 전역 유일
  location             = var.location
  resource_group_name  = module.hub_vnet.resource_group_name
  sku_name             = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  public_network_access_enabled = false
  network_acls = {
    default_action            = "Deny"
    bypass                    = ["AzureServices"]
    virtual_network_subnet_ids = [module.hub_vnet.subnet_ids["pep-snet"], module.hub_vnet.subnet_ids["Monitoring-VM-Subnet"]]
    ip_rules                  = []
  }
  tags = var.tags
}
```

**2) `locals.tf`에 추가**

```hcl
새_kv_name = "${var.project_name}-새이름-kv"   # 예: myproject-app-kv (전역 유일해야 함)
```

---

### 2.5 공통 모듈로 Private Endpoint 추가

**1) `main.tf`에 추가** (대상 리소스가 이미 있어야 함)

```hcl
#--------------------------------------------------------------
# Private Endpoint - Storage Blob (공통 모듈)
#--------------------------------------------------------------
module "pe_새_storage_blob" {
  source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/private-endpoint?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  name                 = "pe-${module.새_storage.storage_account_name}-blob"
  location             = var.location
  resource_group_name  = module.hub_vnet.resource_group_name
  subnet_id            = module.hub_vnet.subnet_ids["pep-snet"]
  target_resource_id   = module.새_storage.storage_account_id
  subresource_names    = ["blob"]
  private_dns_zone_ids = [module.hub_vnet.private_dns_zone_ids["blob"]]
  tags                 = var.tags
}
```

- Key Vault용: `subresource_names = ["vault"]`, `private_dns_zone_ids = [module.hub_vnet.private_dns_zone_ids["vault"]]` 로 바꾸면 됨.

---

### 2.6 루트에 Role Assignment 1개 추가 (모듈 없이)

**1) `main.tf`에 추가**

```hcl
#--------------------------------------------------------------
# Role Assignment: VM → 새 Storage Account
#--------------------------------------------------------------
resource "azurerm_role_assignment" "vm_새_storage_access" {
  provider = azurerm.hub
  count    = var.enable_monitoring_vm ? 1 : 0

  scope                = module.새_storage.storage_account_id
  role_definition_name  = "Storage Blob Data Contributor"
  principal_id          = module.monitoring_vm[0].identity_principal_id
}
```

- `scope`, `principal_id`, `role_definition_name`만 실제 리소스에 맞게 바꾸면 됨.

---

### 2.7 새 변수가 필요할 때 (어디에 무엇을 넣는지)

**1) `variables.tf` 맨 아래에 추가**

```hcl
#--------------------------------------------------------------
# 새 리소스용 변수
#--------------------------------------------------------------
variable "새_리소스_sku" {
  description = "새 리소스 SKU"
  type        = string
  default     = "Standard"
}
```

**2) `terraform.tfvars` (또는 dev.tfvars)에 추가**

```hcl
새_리소스_sku = "Standard"
```

**3) `main.tf`의 해당 모듈/리소스에서 사용**

```hcl
sku = var.새_리소스_sku
```

---

## 3. 리소스 변경 (복사·붙여넣기용)

### 3.1 변수 값만 바꾸기 (이름, SKU, 주소 공간 등)

**수정할 파일**: **`terraform.tfvars`** (또는 환경별 tfvars)

- 해당 변수 줄의 값만 바꾼다.
- 예: `location = "Korea Central"` → `location = "East US"`
- **이름 변경**은 많은 리소스에서 destroy + create를 유발하므로, `terraform plan`으로 반드시 확인 후 apply.

---

### 3.2 공통 모듈 버전만 바꾸기 (ref 변경)

**수정할 파일**: **`main.tf`** (해당 `module` 블록의 `source` 한 줄)

**찾을 내용** (예시):

```hcl
source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=v1.0.0"
```

**바꿀 내용**:

```hcl
source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=v1.1.0"
```

**이후 실행**:

```bash
terraform init -upgrade
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

### 3.3 기본값만 바꾸기 (variables.tf)

**수정할 파일**: **`variables.tf`**

- 해당 `variable "xxx" { ... }` 블록의 `default = "..."` 만 수정.
- 예: `default = "Standard"` → `default = "Premium"`

---

## 4. 리소스 삭제 (복사·붙여넣기용)

### 4.1 루트에서 모듈/리소스 완전 제거

**1) `main.tf`에서 제거**
- 삭제할 `module "xxx" { ... }` 또는 `resource "azurerm_xxx" "yyy" { ... }` **블록 전체**를 삭제.

**2) 다른 곳에서 참조하는지 확인**
- `main.tf` 내 다른 `module`/`resource`에서 `module.삭제할모듈.출력` 이 있으면 그 줄도 삭제하거나, 다른 모듈 출력으로 바꾼다.
- 예: `resource_group_name = module.삭제할모듈.name` → 해당 모듈을 쓰지 않도록 수정.

**3) `outputs.tf`에서 제거**
- 삭제한 모듈/리소스를 참조하는 `output "xxx" { value = module.삭제할모듈.yyy }` 블록 전체 삭제.

**4) `variables.tf`에서 제거 (선택)**
- 그 모듈/리소스에만 쓰이던 변수가 있으면 `variable "xxx" { ... }` 블록 삭제.
- `terraform.tfvars`에서도 해당 변수 줄 삭제.

**5) 실행**

```bash
terraform plan -var-file=terraform.tfvars   # destroy 대상 확인
terraform apply -var-file=terraform.tfvars  # 삭제 적용
```

---

### 4.2 State에서만 제거 (이미 Azure에서 수동 삭제한 경우)

**실행만 하면 됨** (코드 수정 없음):

```bash
# 리소스 1개만 state에서 제거
terraform state rm 'azurerm_storage_account.예시이름'

# 모듈 전체를 state에서 제거
terraform state rm 'module.모듈이름'
```

- **실제 Azure 리소스는 삭제되지 않고**, Terraform이 더 이상 그 리소스를 관리하지 않게 할 때만 사용.

---

### 4.3 리소스는 두고 Terraform 관리만 끊기

**1) 먼저 state에서만 제거**

```bash
terraform state rm 'module.끊을모듈이름'
```

**2) 그 다음 `main.tf`에서 해당 `module "끊을모듈이름" { ... }` 블록 전체 삭제**

- 이렇게 하면 apply 시 destroy가 일어나지 않고, 해당 리소스는 Azure에 남는다.
- 나중에 다시 Terraform으로 관리하려면 `terraform import` 가 필요하다.

---

## 5. 실행 순서 및 주의사항

### 5.1 매번 할 때

```bash
terraform init                                    # 최초 1회 또는 모듈/backend 변경 후
terraform plan -var-file=terraform.tfvars         # 변경 계획 확인 (필수)
terraform apply -var-file=terraform.tfvars        # 적용
```

- plan 파일로 apply 하려면:
  ```bash
  terraform plan -out=tfplan -var-file=terraform.tfvars
  terraform apply tfplan
  ```

### 5.2 공통 모듈 참조 정리

| 내용 | 파일 | 위치 |
|------|------|------|
| **어디에 명시되나?** | **`main.tf`** | 각 `module "..."` 블록의 **`source = "..."`** |
| **레거시 모듈** | `main.tf` | `source = "./modules/경로/모듈명"` |
| **공통 모듈(terraform-modules)** | `main.tf` | `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"` (또는 `?ref=태그`) |
| **버전(ref) 변경** | `main.tf` | 위 `source` 줄에서 `ref=main` → `ref=v1.0.0` 등으로 수정 |

### 5.3 체크리스트 (추가/변경/삭제 시)

- [ ] **추가**: `main.tf`에 module/resource 추가 + 필요 시 `variables.tf`, `locals.tf`, `terraform.tfvars`, `outputs.tf` 수정
- [ ] **변경**: 값만 → `terraform.tfvars` 또는 `variables.tf` default / 공통 모듈 버전 → `main.tf`의 `source` ref
- [ ] **삭제**: `main.tf`에서 블록 삭제 + 다른 곳의 참조(`module.xxx`, `output`) 정리
- [ ] **항상** `terraform plan`으로 생성/변경/삭제 범위 확인 후 apply

---

## 6. 각 환경에 맞추어 수정 필요 항목

이 산출물을 **배포할 환경에 적용**할 때, **해당 환경에 맞게 반드시 수정해야 할 항목**을 정리했습니다.  
아래 표를 기준으로 검색·치환하여 사용하시면 됩니다.

### 6.1 수정 대상 요약

| 구분 | 수정할 내용 | 수정 파일 | 비고 |
|------|-------------|-----------|------|
| **공통 모듈 저장소** | 공통 모듈(terraform-modules) 레포 URL | **`main.tf`** | 맨 위 "공통 모듈 저장소 지정" 주석 + `source = "git::..."` 를 사용하는 모든 module 블록 |
| **Azure 구독 ID** | Hub / Spoke 구독 ID | **`provider.tf`**, **`terraform.tfvars`** | `hub_subscription_id`, `spoke_subscription_id` |
| **리전(Location)** | Azure 리전 | **`terraform.tfvars`**, **`variables.tf`** | `location` (예: Korea Central → East US) |
| **프로젝트/환경 이름** | 프로젝트명, 환경(dev/stage/prod) | **`terraform.tfvars`** | `project_name`, `environment` |
| **네이밍 접두사** | 리소스 이름 접두사 | **`locals.tf`** | `name_prefix` 등 (조직/프로젝트 규칙에 맞게) |
| **Backend(State)** | State 저장소 (Storage Account 등) | **`terraform.tf`** | `backend "azurerm" { ... }` 블록 (resource_group_name, storage_account_name, key 등) |
| **비밀 값** | VPN 공유 키, VM 비밀번호 등 | **`terraform.tfvars`** 또는 환경 변수 | **git에 올리지 말 것**. 해당 환경에서 사용할 값으로 채움 |
| **태그** | 기본 태그 (Project, Environment 등) | **`terraform.tfvars`** | `tags = { ... }` |

### 6.2 공통 모듈 저장소 URL 변경 방법

1. **`main.tf`** 를 연다.
2. **맨 위 주석 블록** — "공통 모듈 저장소 지정" / "공통 모듈 저장소 URL" 부분의 URL을 해당 환경의 terraform-modules 레포 주소로 수정한다.
3. **검색**으로 `https://github.com/kimchibee/terraform-modules.git` (또는 현재 사용 중인 공통 모듈 레포 URL)을 찾아, 해당 환경의 레포 URL로 **일괄 치환**한다.
   - 예: `https://github.com/조직명/terraform-modules.git`
4. 공통 모듈을 참조하는 **모든 `module` 블록**의 `source = "git::..."` 가 새 URL을 가리키는지 확인한다.

### 6.3 Azure 구독·리전 변경

- **`provider.tf`**: `subscription_id` 를 해당 환경의 Hub/Spoke 구독 ID로 변경.
- **`terraform.tfvars`** (또는 환경별 tfvars): `hub_subscription_id`, `spoke_subscription_id`, `location`, `project_name`, `environment`, `tags` 를 해당 환경에 맞게 변경.

### 6.4 Backend(State) 변경

- **`terraform.tf`** 의 `backend "azurerm" { ... }` (또는 사용 중인 backend) 블록에서  
  `resource_group_name`, `storage_account_name`, `container_name`, `key` 등을 해당 환경에서 사용할 State 저장소로 변경.
- 기존 State를 이전하는 경우 별도 `terraform state pull` / `push` 또는 migration 절차가 필요할 수 있음.

### 6.5 각 환경 적용 시 체크리스트

- [ ] 공통 모듈 저장소 URL이 해당 환경의 레포를 가리키는가? (`main.tf` 주석 + 모든 `source = "git::..."` )
- [ ] `provider.tf` / `terraform.tfvars` 의 구독 ID, 리전, 프로젝트명이 해당 환경인가?
- [ ] `terraform.tf` 의 backend가 해당 환경의 State 저장소로 설정되어 있는가?
- [ ] 비밀(구독 ID, VPN 키, VM 비밀번호 등)이 tfvars에 남아 있지 않고, 해당 환경에서 주입할 수 있도록 정리되어 있는가?
- [ ] `locals.tf` 의 네이밍 접두사 등이 해당 환경의 네이밍 규칙에 맞는가?

---

이 가이드는 **복사·붙여넣기로 리소스 생성/변경/삭제**가 가능하도록 작성되었습니다.  
**공통 모듈 저장소**는 **`main.tf` 맨 위 주석("공통 모듈 저장소 지정")** 및 **각 module 블록의 `source` 인자**에 명시되어 있으며,  
각 환경에 맞추어 수정할 때 위 **섹션 6** 항목을 수정하면 됩니다.

---

## 7. 공통 모듈 관리

### 공통 모듈 vs IaC 분리 설계

**목표**: 공통 모듈(terraform-modules)과 IaC(terraform-iac) 두 가지만으로 관리.  
IaC 루트는 **공통 모듈만 호출**하고, 환경 전용/복합 리소스는 IaC 쪽에만 둡니다.

### 공통 모듈로 옮길 수 있는 것 vs IaC에만 둘 것

#### 이미 공통 모듈(terraform-modules)에 있는 것

| 공통 모듈 | 역할 | IaC에서 사용 예 |
|-----------|------|-----------------|
| **resource-group** | RG 1개 | Hub RG, Spoke RG |
| **vnet** | VNet + 서브넷 | Hub VNet, Spoke VNet |
| **storage-account** | Storage Account 1개 | 로그용 스토리지 여러 개 |
| **key-vault** | Key Vault 1개 | Hub KV, Spoke KV |
| **private-endpoint** | PE 1개 + DNS 연결 | Storage/KV/OpenAI 등 PE |

#### 공통 모듈로 추가하면 좋은 것 (단일 책임)

| 현재 위치 | 공통 모듈 후보 | 역할 | 비고 |
|-----------|----------------|------|------|
| monitoring/log-analytics | **log-analytics-workspace** | Workspace 1개만 | Solutions/AG/Dashboard는 IaC 또는 별도 모듈 |
| hub-vnet, spoke-vnet 내 NSG | **nsg** | NSG 1개 + 규칙 | 서브넷마다 반복 |
| hub-vnet 등 diagnostic-settings | **diagnostic-settings** | 리소스 1개당 진단 설정 1건 | VNet/Storage/KV 등 공통 |
| spoke-vnet/vnet-peering, 루트 Peering | **vnet-peering** | 한 방향 Peering 1개 | Hub↔Spoke |
| hub-vnet/private-dns-zones | **private-dns-zone** | Zone 1개 + (선택) VNet Link | Zone 13개 등 반복 |
| compute/vm-monitoring, virtual-machine | **virtual-machine** | Linux/Windows VM 1대 | Monitoring VM 등 |

#### IaC에만 두는 것 (공통 모듈로 안 옮기는 것)

환경/구성에 따라 달라지거나, 한 번에 여러 리소스를 묶는 **조합**에 가까운 것들입니다.

| 리소스/기능 | 이유 |
|-------------|------|
| **VPN Gateway** | Hub 1개, 로컬 게이트웨이/연결 설정 등 환경별 차이 큼 |
| **DNS Private Resolver** | Hub 1개, 인바운드/아웃바운드·ruleset 등 설정 복잡 |
| **API Management** | SKU·VNet·정책 조합이 환경별로 다름 |
| **Azure OpenAI** | 배포/모델 설정이 환경·비즈니스마다 다름 |
| **AI Foundry (ML Workspace 등)** | 워크스페이스·스토리지·ACR 조합, 환경 전용 |
| **Log Analytics Solutions / Action Group / Dashboard** | 모니터링/비즈니스 설정, 환경당 1세트에 가까움 |

### 루트 모듈은 IaC 레포에서, 공통 모듈은 프로젝트 간 공유

- **루트 모듈**(main.tf, variables.tf, outputs.tf, provider.tf, terraform.tf, locals.tf, data.tf)은 **배포의 진입점**이므로 **IaC 레포(terraform-iac)** 에서 관리하는 것이 맞습니다.
- **나중에 다른 Azure 프로젝트가 생기면**:
  - **새 프로젝트용 IaC**를 만듭니다.  
    → 새 레포(예: `terraform-iac-project-b`) 또는 같은 IaC 레포 안에 **새 루트**(예: `environments/project-b/`)를 두는 방식.
  - 그 **새 IaC 루트**에서 **같은 공통 모듈(terraform-modules) 레포**를 참조합니다.  
    → `source = "git::https://github.com/.../terraform-modules.git//terraform_modules/xxx?ref=v1.0.0"` 형태로 그대로 사용.

이렇게 하면:
- **공통 모듈**을 한 레포에서만 관리하므로, 버그 수정·개선을 반영하면 **그 공통 모듈을 쓰는 모든 Azure 프로젝트**에서 동일한 품질을 유지할 수 있습니다.
- **프로젝트별 차이**(구독, 네이밍, 기능 on/off)는 **각 IaC 루트의 variables·locals·모듈 호출 인자**에서만 다르게 두면 됩니다.

---

## 8. 루트 파일 관리

### 루트 vs IaC 모듈 — 누가 누구에 종속?

**루트 .tf가 IaC 모듈에 종속되는 것이 아닙니다.** 반대입니다.

- **루트** = `terraform apply`의 **진입점(주체)**.  
  루트의 **main.tf**가 **공통 모듈**과 **IaC 모듈**을 **호출**합니다.
- **공통 모듈 / IaC 모듈** = 루트에 **의해 호출되는** 쪽.  
  즉, **모듈들이 루트에 종속**됩니다 (루트가 없으면 호출될 수 없음).

### Terraform 배포 시 흐름

1. **루트**에서 `terraform plan` / `apply` 실행.
2. **루트 main.tf**가 **공통 모듈**과 **IaC 모듈**을 호출할 때,  
   **variables.tf / locals.tf**에 정의된 값(리소스 그룹명, VNet명, 주소 공간, 태그 등)을 **인자로 넘깁니다.**
3. 각 모듈은 그 인자에 맞춰 **Azure 리소스**를 생성/갱신합니다.  
   → 루트에 명시된 **리소스 그룹명, VNet명 등**에 맞춰 **특정 Azure 인프라(구독·리전)** 에 **Azure 서비스**가 배포됩니다.
4. **provider.tf**의 구독 ID(Hub/Spoke)와 **terraform.tf**의 Backend 설정에 따라, **어느 구독·어디에 상태를 저장할지**가 정해집니다.

### 루트 .tf 파일은 보통 어떻게 관리하나?

#### 1. 버전 관리 (Git)

- **루트 .tf 전체**를 Git 저장소(예: terraform-iac 레포)에 둡니다.
- **main.tf, variables.tf, outputs.tf, provider.tf, terraform.tf, locals.tf, data.tf** 는 모두 커밋 대상.
- 변경 이력·리뷰·롤백을 위해 **브랜치 전략**(main + feature 브랜치 등)을 정합니다.

#### 2. 환경별 값 분리 — tfvars

- **variables.tf** 에는 변수 **정의**만 두고, **실제 값**은 **tfvars** 로 분리합니다.
- **terraform.tfvars** 는 예시만 커밋하고(terraform.tfvars.example), **실제 값이 들어간 terraform.tfvars** 는 **.gitignore** 에 넣어 Git에 올리지 않습니다.
- 환경별로 파일을 나누면:
  - `dev.tfvars`, `staging.tfvars`, `prod.tfvars` 등
  - 실행 시: `terraform plan -var-file=prod.tfvars`
- 비밀(구독 ID, 비밀번호 등)은 tfvars 대신 **환경 변수**(`TF_VAR_xxx`) 또는 **Azure Key Vault 등**에서 주입하는 방식을 많이 씁니다.

#### 3. State(상태) 관리 — Backend

- **terraform.tf** 에 **backend "azurerm"** 또는 **backend "s3"** 등을 설정해, **state 파일**을 **원격 스토리지**에 저장합니다.
- 팀원이 같은 state를 보도록 하고, **state 잠금**으로 동시 apply 충돌을 막습니다.
- 환경/구독마다 **backend key** 를 다르게 두면(예: `key = "prod/terraform.tfstate"`) 환경별 state 분리가 됩니다.

| 대상 | 권장 저장소 | 버전 관리 |
|------|-------------|-----------|
| **State** | S3 / Azure Blob / GCS (backend) | ✅ 버킷 버전 관리 권장 (state 복구용) |
| **루트 .tf 코드** | **Git** (GitHub 등) | ✅ Git으로 버전 관리. S3는 백업/아카이브용으로만 선택적 사용 |

#### 4. 환경별 루트를 나누는 방법 (선택)

- **한 루트에 tfvars만 바꿔 쓰는 방식**  
  - 루트 .tf는 한 세트. `-var-file=dev.tfvars` / `prod.tfvars` 로 구분.
- **환경마다 디렉터리를 두는 방식**  
  - 예: `environments/dev/`, `environments/prod/`  
  - 각 디렉터리에 **자기 환경용** main.tf, variables.tf, provider.tf, terraform.tf, tfvars 를 두고, 공통 모듈은 `source = "../../modules/..."` 또는 git으로 참조.

### 루트에 꼭 있어야 하는 파일 (옮기면 안 됨)

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

## 9. HashiCorp 권장 사항

### 1. 표준 모듈 구조 (Standard Module Structure)

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

### 2. 버전 관리 + 코드 리뷰

- **모든 Terraform 코드를 VCS(Git 등)에** 넣기.
- **Pull Request(코드 리뷰)** 후 머지.
- **수동 변경 최소화** — 변경은 코드로 하고, apply는 파이프라인 또는 통제된 절차로.

### 3. 원격 State + 잠금 (Remote State with Locking)

- **State는 원격 Backend**에 저장 (로컬 기본값 사용 지양).
- **State locking**으로 동시 apply 충돌 방지.
- 지원 Backend 예: **azurerm**, **s3**, **gcs**, **remote**(HCP Terraform) 등.

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

### 4. 비밀/민감 데이터 관리

- **variable**에 비밀/민감 값이면 `sensitive = true` 지정.
- **실제 비밀 값**은 tfvars 파일에 넣지 말고, **환경 변수**(`TF_VAR_xxx`) 또는 **HCP Terraform / Vault** 등에서 주입.
- **State**에 민감 정보가 들어가지 않도록, 가능하면 **ephemeral** 값 사용(Terraform 1.10+).

### 5. 환경 분리 — Workspace vs 디렉터리

- **Workspace**
  - **같은 코드**로 **여러 state**만 나누고 싶을 때 사용.
  - `${terraform.workspace}` 로 이름만 구분.
  - **서로 다른 구독/권한/설정**이 크게 다르면 부적합.
- **환경별로 설정이 크게 다를 때**
  - **환경마다 디렉터리** (`environments/dev/`, `environments/prod/`)를 두고,  
    각 디렉터리에 루트 .tf + 해당 환경용 tfvars/backend key를 두는 방식을 권장.

### 6. 코드 스타일 및 검증

- **`terraform fmt`** — 커밋 전 포맷 통일.
- **`terraform validate`** — 문법/구성 검증.
- **리소스 이름** — 타입 이름 제외, 명사 사용, 단어 구분은 언더스코어(`_`).
- **들여쓰기** — 2칸 스페이스.

### 체크리스트 — 지금 프로젝트에 적용할 수 있는 것

| 항목 | HashiCorp 권장 | 적용 방법 (terraform-iac) |
|------|----------------|------------------------------|
| **루트 구조** | main.tf, variables.tf, outputs.tf 등 루트에 진입점 유지 | ✅ 이미 루트 .tf로 구성됨 |
| **모듈 구조** | modules/ 또는 별도 레포, README·description | ✅ 공통 모듈은 terraform-modules 레포, IaC 모듈은 `modules/`. description 보강 권장 |
| **버전 관리** | 전체 코드 Git, PR 리뷰 | ✅ Git 사용. PR 워크플로우 적용 권장 |
| **원격 State** | backend로 원격 저장 + 잠금 | ⬜ `terraform.tf`에서 backend "azurerm" (또는 사용 Backend) 설정 |
| **비밀** | sensitive = true, tfvars 미커밋, TF_VAR 또는 시크릿 저장소 | ⬜ 비밀 변수에 sensitive 추가, tfvars는 .gitignore |
| **환경 분리** | Workspace 또는 environments/ 디렉터리 | ⬜ tfvars로 분리 중이면 유지. 필요 시 environments/dev\|prod 도입 |
| **스타일/검증** | fmt, validate | ⬜ CI 또는 pre-commit에 `terraform fmt -recursive`, `terraform validate` 추가 |

---

## 10. 작업 절차

### 사전 준비사항

#### 1. 필수 도구 설치

- **Azure CLI**: [설치 가이드](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Terraform**: 버전 **~> 1.5** 이상
  - 확인: `terraform version`

#### 2. Azure 인증

```bash
# Azure에 로그인
az login

# 현재 로그인된 계정 확인
az account show

# 필요한 구독으로 전환
az account set --subscription "<subscription-id>"
```

#### 3. 권한 확인

- **Subscription 레벨**: `Contributor` 또는 `Owner` 권한
- **Resource Group 레벨**: 리소스 생성/수정/삭제 권한

#### 4. 설정 파일 확인

`terraform.tfvars` 파일에 실제 환경 값이 설정되어 있는지 확인:

```hcl
hub_subscription_id   = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
spoke_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 기본 작업 흐름

#### 1. Terraform 초기화

```bash
terraform init
```

#### 2. 실행 계획 확인

```bash
terraform plan
```

#### 3. 변경사항 적용

```bash
terraform apply

# 자동 승인 (주의: 확인 없이 적용됨)
terraform apply -auto-approve
```

#### 4. 특정 리소스만 적용

```bash
# 특정 모듈만 적용
terraform apply -target=module.vm_linux_01

# 특정 리소스만 적용
terraform apply -target=module.hub_vnet.azurerm_virtual_network.hub
```

### State 관리

#### State 확인

```bash
# State 목록 확인
terraform state list

# 특정 리소스 State 확인
terraform state show module.vm_linux_01.module.vm.azurerm_linux_virtual_machine.this[0]

# State 출력
terraform output
```

#### State 제거 (리소스는 유지)

```bash
terraform state rm <resource-address>
```

#### State 백업

```bash
cp terraform.tfstate terraform.tfstate.backup
```

### 문제 해결

#### 1. Azure 인증 오류

```bash
az login
az account show
```

#### 2. Provider 초기화 오류

```bash
terraform init -upgrade
```

#### 3. State 파일 오류

```bash
# State 파일 존재 확인
ls -la terraform.tfstate

# State 파일 복원
cp terraform.tfstate.backup terraform.tfstate
```

#### 4. 의존성 오류

```bash
# 의존성 그래프 확인
terraform graph | dot -Tsvg > graph.svg
```

### 체크리스트

#### 작업 전 확인사항

- [ ] Azure CLI 설치 및 로그인 완료
- [ ] Terraform 버전 확인 (~> 1.5)
- [ ] `terraform.tfvars` 파일 확인/수정
  - [ ] `hub_subscription_id` 설정 확인
  - [ ] `spoke_subscription_id` 설정 확인
- [ ] Azure 권한 확인 (Subscription Contributor 이상)
- [ ] `terraform.tfstate` 파일 존재 확인
- [ ] `terraform init` 실행 완료

#### 리소스 추가 전 확인사항

- [ ] 모듈 디렉터리 구조 확인
- [ ] 변수 정의 완료 (`variables.tf`)
- [ ] 출력 값 정의 완료 (`outputs.tf`)
- [ ] 루트 `main.tf`에 모듈 호출 추가
- [ ] 의존성 관계 확인 (`depends_on`)

#### 리소스 삭제 전 확인사항

- [ ] 다른 모듈에서 참조하는지 확인
- [ ] State에서 제거할 리소스 주소 확인
- [ ] 실제 리소스 삭제 여부 결정
- [ ] 백업 완료

---

## 11. 배포된 인프라 정보

### 인프라 일치도: ✅ **완벽히 일치**

배포된 Azure 인프라와 Terraform 구조가 완벽히 일치합니다.

### 전체 리소스 통계

| 항목 | 배포된 인프라 | Terraform 구조 | 일치 여부 |
|------|-------------|---------------|----------|
| 총 모듈 | 5개 | 5개 | ✅ |
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

#### 1. 모듈화된 구조
- 각 기능별로 모듈 분리
- 재사용 가능한 구조
- 명확한 의존성 관리

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

**마지막 업데이트**: 2026-01-23  
**환경**: test  
**위치**: Korea Central  
**Terraform 버전**: ~> 1.5
