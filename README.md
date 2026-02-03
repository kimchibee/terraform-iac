# Terraform IaC (Azure 인프라 배포)

이 저장소는 **Azure 인프라의 배포 루트**입니다.  
Provider·Backend·환경별 변수를 관리하고, `terraform plan` / `terraform apply`를 여기서 실행합니다.

---

## 공통 모듈 참조는 어디에 있나?

**공통 모듈(terraform-modules) 참조는 `main.tf`에만 있습니다.**

- **파일**: **`main.tf`** (루트)
- **위치**: 각 `module "..."` 블록 안의 **`source = "..."`** 인자
- **레거시 모듈**: `source = "./modules/경로/모듈명"` (예: `./modules/networking/hub-vnet`)
- **공통 모듈(terraform-modules 레포)**: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=v1.0.0"`

즉, **모듈을 추가·변경·삭제할 때 수정하는 파일은 `main.tf`** 이고,  
공통 모듈 버전을 바꿀 때도 `main.tf`의 해당 `module` 블록에서 `source`의 `ref=` 값만 바꾸면 됩니다.

---

## 목차

1. [파일별 역할 (어디를 고치면 되는지)](#1-파일별-역할-어디를-고치면-되는지)
2. [리소스 추가 (복사·붙여넣기용)](#2-리소스-추가-복사붙여넣기용)
3. [리소스 변경 (복사·붙여넣기용)](#3-리소스-변경-복사붙여넣기용)
4. [리소스 삭제 (복사·붙여넣기용)](#4-리소스-삭제-복사붙여넣기용)
5. [실행 순서 및 주의사항](#5-실행-순서-및-주의사항)

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

이 가이드는 **복사·붙여넣기로 리소스 생성/변경/삭제**가 가능하도록 작성되었습니다.  
공통 모듈 참조는 **`main.tf`의 각 module 블록 `source` 인자**에만 있으며, 레거시는 `./modules/`, 공통 모듈은 `git::...terraform-modules...?ref=...` 로 구분됩니다.
