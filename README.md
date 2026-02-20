# Terraform IaC (Azure 인프라 배포)

이 저장소는 **AWS 스택 분리 방식**을 적용하여 Azure Hub/Spoke 인프라를 관리합니다.  
각 스택을 **독립적으로 배포/롤백**할 수 있으며, **State 파일이 분리**되어 있습니다.

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

```bash
cd ../ai-services
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 파일 수정

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

**생성 리소스:**
- Azure OpenAI (Cognitive Service)
- AI Foundry (Azure Machine Learning Workspace)
- Private Endpoints for AI Services

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
3. **모든 dev 스택 한 번에 검증** (각 스택에서 `terraform init -backend=false` 후 스크립트 실행):
   - **PowerShell 실행 정책** 때문에 `.ps1` 실행이 막히면 **`run-all-validate.cmd`** 더블클릭 또는 `.\run-all-validate.cmd` 실행.
   - 또는: `powershell -ExecutionPolicy Bypass -File .\run-all-validate.ps1`
   ```powershell
   cd azure/dev
   .\run-all-validate.cmd
   # 또는 .\run-all-validate.ps1  (실행 정책 허용 시)
   ```
   - 순서: network → storage → shared-services → apim → ai-services → compute → connectivity
   - **network**는 모듈 갱신 후 `terraform init -upgrade -backend=false` 권장.
4. **한 스택씩 검증**은 아래 "스택별 init/validate 명령" 표 참고.
5. 자세한 요구사항·이슈 대응은 **terraform-modules** 레포의 `README.md` 참고.

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
