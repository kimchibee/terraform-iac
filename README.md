# Terraform IaC (Azure 인프라 배포)

이 저장소는 **IaC 레포**이며, **루트 모듈**이 여기서 관리됩니다.  
Azure Hub/Spoke 인프라를 Terraform으로 배포할 때 `terraform plan` / `terraform apply`는 **이 레포 루트**에서 실행합니다.

---

## 이 레포에서 관리하는 것 (루트 모듈)

| 구분 | 내용 |
|------|------|
| **루트 모듈** | `main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `terraform.tf`, `locals.tf`, `data.tf` — 배포 진입점. **이 레포 루트에 있음.** |
| **IaC 전용 모듈** | `modules/` — **환경별**(예: `dev/`) 하위에 **Hub**(vnet, shared-services, monitoring-storage) / **Spoke**(vnet) 기준, 이 프로젝트 전용. |
| **공통 모듈** | **[terraform-modules](https://github.com/kimchibee/terraform-modules)** 레포에서 관리. 이 레포(terraform-iac)에는 포함하지 않으며, `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=태그"` 로만 참조. |

다른 Azure 프로젝트가 생기면 **새 IaC(새 레포 또는 `environments/` 하위)** 를 만들고, **같은 공통 모듈(terraform-modules) 레포**를 참조해 같이 쓸 수 있습니다. → [docs/COMMON_MODULE_MIGRATION.md](docs/COMMON_MODULE_MIGRATION.md) §6 참고.

---

## 빠른 시작

1. **사전 요구**  
   Terraform 1.5+, Azure CLI 로그인(`az login`), Hub/Spoke 구독 ID 확보.

2. **클론**  
   `git clone <이 레포 URL>` 후 `cd <레포 루트>`.

3. **변수 파일**  
   `cp terraform.tfvars.example terraform.tfvars` 후 구독 ID, 리전, 프로젝트명, 비밀 등 환경에 맞게 수정.  
   (`terraform.tfvars` 는 .gitignore 대상 — 커밋하지 말 것.)

4. **초기화 및 배포**  
   ```bash
   terraform init   # 공통 모듈은 terraform-modules 레포에서 자동 다운로드
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
   환경별로 `dev.tfvars`, `prod.tfvars` 등을 쓰면:  
   `terraform plan -var-file=prod.tfvars`

5. **Backend(State)**  
   원격 State 사용 시 `terraform.tf` 에서 `backend "azurerm" { ... }` 주석 해제 후, 사용할 Storage 계정·컨테이너·key 로 수정.

---

## 문서 (상세 가이드)

| 문서 | 설명 |
|------|------|
| [docs/COMMON_MODULE_MIGRATION.md](docs/COMMON_MODULE_MIGRATION.md) | 공통 모듈 vs IaC 분리 설계, 루트 모듈은 IaC에서 관리, 다른 프로젝트 시 공통 모듈 공유 |
| [docs/ROOT_TF_FILES.md](docs/ROOT_TF_FILES.md) | 루트 .tf 역할, 루트 vs 모듈 관계, 배포 흐름, 루트 .tf 관리 방법 |
| [docs/HASHICORP_RECOMMENDED_PRACTICES.md](docs/HASHICORP_RECOMMENDED_PRACTICES.md) | HashiCorp 권장 사항 — 표준 모듈 구조, 원격 State, 비밀, 환경 분리, fmt/validate |

---

## 공통 모듈 참조는 어디에 있나?

**공통 모듈(terraform-modules) 참조는 `main.tf`에만 있습니다.**

- **공통 모듈 저장소 주소**: **`https://github.com/kimchibee/terraform-modules.git`**
- **파일**: **`main.tf`** (루트)
- **위치**:
  - **명시 위치**: `main.tf` **맨 위 주석 블록** — "공통 모듈 저장소 지정" 으로 검색하면 됨.
  - **실제 사용 위치**: 각 `module "..."` 블록 안의 **`source = "..."`** 인자 (공통 모듈을 쓸 때)
- **IaC 모듈**: `source = "./modules/환경/경로/모듈명"` (예: `./modules/dev/hub/vnet`, `./modules/dev/spoke/vnet`)
- **공통 모듈(terraform-modules 레포)**: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=v1.0.0"`

즉, **모듈을 추가·변경·삭제할 때 수정하는 파일은 `main.tf`** 이고,  
공통 모듈 버전을 바꿀 때는 `main.tf`의 해당 `module` 블록에서 `source`의 `ref=` 값만 바꾸면 됩니다.  
**각 환경에 맞추어 수정할 때**는 아래 [각 환경에 맞추어 수정 필요 항목](#6-각-환경에-맞추어-수정-필요-항목) 에서 공통 모듈 저장소 URL 등 수정 대상을 확인하세요.

---

## 파일 및 디렉터리 계층 구조

```
terraform-config/                    # 루트 (IaC 배포 루트)
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
- **공통 모듈**: [terraform-modules](https://github.com/kimchibee/terraform-modules) 레포에서 관리 (log-analytics-workspace, nsg, diagnostic-settings, vnet-peering, private-dns-zone, virtual-machine 등). 이 레포에는 포함하지 않으며 `?ref=태그` 로 버전 지정.
- **IaC 모듈**: `modules/` — **환경별**(예: `dev/`) 하위에 **Hub**(`dev/hub/vnet`, `dev/hub/shared-services`, `dev/hub/monitoring-storage`) / **Spoke**(`dev/spoke/vnet`) 기준으로 구분, 루트에서만 호출.

---

## 목차

1. [파일별 역할 (어디를 고치면 되는지)](#1-파일별-역할-어디를-고치면-되는지)
2. [리소스 추가 (복사·붙여넣기용)](#2-리소스-추가-복사붙여넣기용)
3. [리소스 변경 (복사·붙여넣기용)](#3-리소스-변경-복사붙여넣기용)
4. [리소스 삭제 (복사·붙여넣기용)](#4-리소스-삭제-복사붙여넣기용)
5. [실행 순서 및 주의사항](#5-실행-순서-및-주의사항)
6. [각 환경에 맞추어 수정 필요 항목](#6-각-환경에-맞추어-수정-필요-항목)

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
| **공통 모듈(terraform-modules)** | `main.tf` | `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=v1.0.0"` |
| **버전(ref) 변경** | `main.tf` | 위 `source` 줄에서 `ref=v1.0.0` → `ref=v1.1.0` 등으로 수정 |

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
