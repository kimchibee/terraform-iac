# Terraform 인프라 관리 가이드

## 📋 목차

1. [전체 아키텍처](#전체-아키텍처)
2. [Terraform 구조](#terraform-구조)
3. [공통 모듈 관리](#공통-모듈-관리)
4. [리소스 추가/변경/삭제](#리소스-추가변경삭제)
5. [작업 절차](#작업-절차)

---

## 전체 아키텍처

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

## Terraform 구조

### 루트 레벨 파일 구조

```
terraform-config/
├── main.tf                    # 모듈 호출 및 핵심 리소스 정의
├── variables.tf               # 입력 변수 정의
├── terraform.tf               # Terraform 설정 (버전, providers, backend)
├── provider.tf                # Provider 설정 (azurerm hub/spoke)
├── data.tf                    # Data 소스 정의
├── locals.tf                  # Local 값 정의 (네이밍, 태그)
├── outputs.tf                 # 출력 값 정의
├── terraform.tfvars           # 실제 값 설정 (환경별)
└── config/                    # 설정 파일 디렉터리
    ├── acr-policy.json
    ├── apim-policy.xml
    └── openai-deployments.json
```

### 파일 역할 설명

#### main.tf
- **역할**: 모듈 호출 및 핵심 리소스 정의
- **내용**: Hub VNet, Shared Services, Storage, Monitoring VM, Spoke VNet 모듈 호출, Role Assignment 리소스

#### variables.tf
- **역할**: 외부에서 입력받는 변수 정의
- **내용**: 프로젝트명, 환경, 위치, 네트워크 설정, VM 설정, Feature Flags 등

#### terraform.tf
- **역할**: Terraform 설정 블록
- **내용**: 
  - `required_version = "~> 1.5"`
  - `required_providers` (azurerm, azapi, random)
  - Backend 설정 (주석 처리, 필요시 활성화)

#### provider.tf
- **역할**: Provider 설정
- **내용**: 
  - Hub Subscription Provider (alias: "hub")
  - Spoke Subscription Provider (alias: "spoke")
  - Default Provider (Hub)
  - azapi Provider

#### data.tf
- **역할**: 조회 전용 데이터 소스 정의
- **내용**: `azurerm_client_config`, 기존 리소스 조회 예시

#### locals.tf
- **역할**: 공통 값 정의 (DRY 원칙)
- **내용**: 네이밍 prefix, 리소스 이름, 공통 태그

#### outputs.tf
- **역할**: 외부로 반환할 값 정의
- **내용**: VNet ID, 서브넷 ID, Key Vault URI, API Management URL 등

#### terraform.tfvars
- **역할**: 실제 값 설정
- **내용**: 환경별 차이 반영 (staging, prod로 복사하여 사용)

### 모듈 디렉터리 구조

```
modules/
├── networking/                # 네트워킹 관련 모듈
│   ├── hub-vnet/             # Hub Virtual Network
│   │   ├── main.tf            # VNet, Subnets, NSG
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── vpn-gateway.tf    # VPN Gateway
│   │   ├── dns-resolver.tf   # DNS Private Resolver
│   │   ├── private-dns-zones.tf  # Private DNS Zones
│   │   └── diagnostic-settings.tf
│   └── spoke-vnet/           # Spoke Virtual Network
│       ├── main.tf            # VNet, Subnets, NSG
│       ├── variables.tf
│       ├── outputs.tf
│       ├── apim.tf            # API Management
│       ├── openai.tf          # Azure OpenAI
│       ├── ai-foundry.tf      # AI Foundry
│       └── vnet-peering.tf   # VNet Peering
├── connectivity/              # 연결성 관련 모듈
│   ├── vpn-gateway/          # VPN Gateway (독립 모듈)
│   ├── dns-resolver/         # DNS Resolver (독립 모듈)
│   └── vnet-peering/         # VNet Peering (독립 모듈)
├── compute/                   # 컴퓨팅 관련 모듈
│   ├── virtual-machine/      # 공통 VM 모듈
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vm-monitoring/        # Monitoring VM 인스턴스
│   ├── vm-linux-01/          # Linux VM 인스턴스
│   └── vm-windows-01/        # Windows VM 인스턴스
├── storage/                   # 스토리지 관련 모듈
│   ├── key-vault/            # Key Vault (독립 모듈)
│   └── monitoring-storage/    # Monitoring Storage Accounts
│       ├── main.tf            # Storage Accounts
│       ├── keyvault.tf        # Key Vault
│       ├── variables.tf
│       └── outputs.tf
├── api-management/            # API Management 모듈
│   └── apim/                 # API Management
├── ai-services/               # AI 서비스 모듈
│   ├── openai/               # Azure OpenAI
│   └── ai-foundry/           # AI Foundry
├── monitoring/                # 모니터링 모듈
│   ├── log-analytics/        # Log Analytics Workspace
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── diagnostic-settings/  # Diagnostic Settings
├── security/                  # 보안 모듈
└── examples/                  # 예제 모듈
```

### 모듈 구조 패턴

#### 공통 모듈 + 인스턴스 패턴

```
modules/compute/
├── virtual-machine/     # 공통 모듈 (실제 리소스 정의)
│   ├── main.tf          # VM, NIC, Disk 등 리소스
│   ├── variables.tf     # 입력 변수
│   └── outputs.tf       # 출력 값
│
├── vm-linux-01/         # 인스턴스 (값만 지정)
│   ├── main.tf          # module "virtual-machine" 호출
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars # 실제 값
│
└── vm-windows-01/       # 인스턴스 (값만 지정)
    ├── main.tf          # module "virtual-machine" 호출
    ├── variables.tf
    ├── outputs.tf
    └── terraform.tfvars # 실제 값
```

**장점:**
- 공통 로직 재사용 (DRY 원칙)
- 서브넷 변경 시 인스턴스만 복사하여 값 변경
- 유지보수 용이

---

## 공통 모듈 관리

### _vm-module (VM 공통 모듈)

#### 위치
`modules/compute/virtual-machine/`

#### 주요 기능
- **Linux/Windows VM 모두 지원**: `os_type` 변수로 선택
- **Network Interface**: 자동 생성
- **OS Disk**: 설정 가능 (caching, storage_account_type, disk_size_gb)
- **VM Extensions**: 선택적 추가
- **Managed Identity**: System Assigned 지원

#### 구조
```
virtual-machine/
├── main.tf          # 리소스 정의
│   ├── azurerm_network_interface
│   ├── azurerm_linux_virtual_machine (조건부)
│   ├── azurerm_windows_virtual_machine (조건부)
│   └── azurerm_virtual_machine_extension (for_each)
├── variables.tf     # 입력 변수
└── outputs.tf       # 출력 값
```

#### 사용 예시
```hcl
# 인스턴스 모듈에서 호출
module "vm" {
  source = "../_vm-module"

  name                = var.vm_name
  os_type             = "linux"  # 또는 "windows"
  size                = var.vm_size
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = data.azurerm_subnet.selected.id
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags
}
```

#### 공통 모듈 수정 방법

1. **변수 추가**
   ```hcl
   # _vm-module/variables.tf
   variable "new_feature" {
     description = "새 기능 설명"
     type        = string
     default     = "default_value"
   }
   ```

2. **리소스 추가**
   ```hcl
   # _vm-module/main.tf
   resource "azurerm_<resource_type>" "new_resource" {
     # 리소스 설정
   }
   ```

3. **출력 값 추가**
   ```hcl
   # _vm-module/outputs.tf
   output "new_output" {
     description = "출력 값 설명"
     value       = azurerm_<resource_type>.new_resource.id
   }
   ```

4. **인스턴스 모듈 업데이트**
   - 모든 인스턴스 모듈의 `variables.tf`에 새 변수 추가
   - `main.tf`에서 공통 모듈 호출 시 새 변수 전달

### 서브넷 조회 패턴

인스턴스 모듈은 VNet에서 서브넷을 자동으로 조회합니다:

```hcl
# VNet 조회
data "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  resource_group_name = var.vnet_resource_group_name
}

# 서브넷 조회 (subnet_name으로 필터링)
data "azurerm_subnet" "selected" {
  name                 = var.subnet_name
  virtual_network_name  = var.vnet_name
  resource_group_name  = var.vnet_resource_group_name
}
```

**서브넷 변경 방법:**
- 각 인스턴스의 `terraform.tfvars`에서 `subnet_name`만 수정
- 예: `subnet_name = "snet-app"` → `subnet_name = "snet-database"`

---

## 리소스 추가/변경/삭제

### 리소스 추가

#### 1. 새 모듈 추가

**예: 새 워크로드 모듈 추가**

```bash
# 1. 모듈 디렉터리 생성 (서비스 카테고리에 맞게)
mkdir -p modules/examples/new-service

# 2. 기본 파일 생성
touch modules/examples/new-service/{main.tf,variables.tf,outputs.tf}
```

**main.tf 작성:**
```hcl
# modules/examples/new-service/main.tf
resource "azurerm_<resource_type>" "new_service" {
  name                = "${var.project_name}-new-service"
  location            = var.location
  resource_group_name = var.resource_group_name
  # ... 기타 설정
}
```

**variables.tf 작성:**
```hcl
# modules/examples/new-service/variables.tf
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
}

variable "location" {
  description = "Azure 리전"
  type        = string
}

variable "resource_group_name" {
  description = "Resource Group 이름"
  type        = string
}
```

**outputs.tf 작성:**
```hcl
# modules/examples/new-service/outputs.tf
output "service_id" {
  description = "서비스 ID"
  value       = azurerm_<resource_type>.new_service.id
}
```

**루트 main.tf에서 호출:**
```hcl
# 루트 main.tf
module "new_service" {
  source = "./modules/examples/new-service"

  providers = {
    azurerm = azurerm.hub  # 또는 azurerm.spoke
  }

  project_name        = var.project_name
  location           = var.location
  resource_group_name = module.hub_vnet.resource_group_name

  depends_on = [module.hub_vnet]
}
```

#### 2. 기존 모듈에 리소스 추가

**예: Hub VNet 모듈에 Firewall 추가**

```bash
# 1. 새 리소스 파일 생성
touch modules/networking/hub-vnet/firewall.tf
```

**firewall.tf 작성:**
```hcl
# modules/networking/hub-vnet/firewall.tf
resource "azurerm_firewall" "hub_firewall" {
  name                = "${var.project_name}-hub-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = var.firewall_sku
  # ... 기타 설정
}
```

**variables.tf에 변수 추가:**
```hcl
# modules/networking/hub-vnet/variables.tf
variable "firewall_sku" {
  description = "Firewall SKU"
  type        = string
  default     = "Standard"
}
```

**outputs.tf에 출력 값 추가:**
```hcl
# modules/networking/hub-vnet/outputs.tf
output "firewall_id" {
  description = "Hub Firewall ID"
  value       = azurerm_firewall.hub_firewall.id
}
```

#### 3. 새 VM 인스턴스 추가

**예: 새 Linux VM 인스턴스 추가**

```bash
# 1. 기존 인스턴스 복사
cp -r modules/compute/vm-linux-01 modules/compute/vm-linux-02

# 2. terraform.tfvars 수정
# modules/compute/vm-linux-02/terraform.tfvars
vm_name = "test-x-x-vm-linux-02"
subnet_name = "snet-web"  # 서브넷 변경
```

**루트 main.tf에서 호출:**
```hcl
# 루트 main.tf
module "vm_linux_02" {
  source = "./modules/compute/vm-linux-02"
  count  = var.enable_vm_linux_02 ? 1 : 0

  providers = {
    azurerm = azurerm.hub
  }

  vm_name                = "test-x-x-vm-linux-02"
  vm_size                = var.vm_size
  location               = var.location
  resource_group_name    = module.hub_vnet.resource_group_name
  vnet_name              = module.hub_vnet.vnet_name
  vnet_resource_group_name = module.hub_vnet.resource_group_name
  subnet_name            = "snet-web"
  admin_username         = var.vm_admin_username
  admin_password         = var.vm_admin_password
  tags                   = var.tags

  depends_on = [module.hub_vnet]
}
```

### 리소스 변경

#### 1. 리소스 설정 변경

**예: VM 크기 변경**

```hcl
# 루트 main.tf 또는 인스턴스 모듈의 terraform.tfvars
vm_size = "Standard_B4s"  # 기존: Standard_B2s
```

#### 2. 변수 기본값 변경

```hcl
# variables.tf
variable "vm_size" {
  description = "VM 크기"
  type        = string
  default     = "Standard_B4s"  # 변경
}
```

#### 3. 네트워크 설정 변경

```hcl
# terraform.tfvars
hub_subnets = {
  "Monitoring-VM-Subnet" = {
    address_prefixes = ["10.0.1.0/24"]  # 변경
    # ...
  }
}
```

### 리소스 삭제

#### 1. 모듈 삭제

**예: VM 인스턴스 삭제**

```bash
# 1. 루트 main.tf에서 모듈 호출 제거
# module "vm_linux_01" { ... } 삭제

# 2. State에서 제거 (리소스는 유지)
terraform state rm module.vm_linux_01

# 3. 실제 리소스 삭제 (선택사항)
terraform destroy -target=module.vm_linux_01

# 4. 디렉터리 삭제
rm -rf modules/compute/vm-linux-01
```

#### 2. 모듈 내 리소스 삭제

**예: Hub VNet 모듈에서 Firewall 삭제**

```bash
# 1. 리소스 파일 삭제
rm modules/networking/hub-vnet/firewall.tf

# 2. variables.tf에서 관련 변수 제거
# variable "firewall_sku" { ... } 삭제

# 3. outputs.tf에서 관련 출력 값 제거
# output "firewall_id" { ... } 삭제

# 4. State에서 제거
terraform state rm module.hub_vnet.azurerm_firewall.hub_firewall

# 5. 실제 리소스 삭제 (선택사항)
terraform destroy -target=module.hub_vnet.azurerm_firewall.hub_firewall
```

#### 3. 의존성 정리

리소스를 삭제할 때는 다른 모듈에서 참조하는 출력 값도 확인해야 합니다:

```hcl
# 다른 모듈에서 참조하는 경우
module "other_module" {
  # ...
  firewall_id = module.hub_vnet.firewall_id  # 이 참조도 제거 필요
}
```

---

## 작업 절차

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

---

## 체크리스트

### 작업 전 확인사항

- [ ] Azure CLI 설치 및 로그인 완료
- [ ] Terraform 버전 확인 (~> 1.5)
- [ ] `terraform.tfvars` 파일 확인/수정
  - [ ] `hub_subscription_id` 설정 확인
  - [ ] `spoke_subscription_id` 설정 확인
- [ ] Azure 권한 확인 (Subscription Contributor 이상)
- [ ] `terraform.tfstate` 파일 존재 확인
- [ ] `terraform init` 실행 완료

### 리소스 추가 전 확인사항

- [ ] 모듈 디렉터리 구조 확인
- [ ] 변수 정의 완료 (`variables.tf`)
- [ ] 출력 값 정의 완료 (`outputs.tf`)
- [ ] 루트 `main.tf`에 모듈 호출 추가
- [ ] 의존성 관계 확인 (`depends_on`)

### 리소스 삭제 전 확인사항

- [ ] 다른 모듈에서 참조하는지 확인
- [ ] State에서 제거할 리소스 주소 확인
- [ ] 실제 리소스 삭제 여부 결정
- [ ] 백업 완료

---

## 참고 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [Azure Provider 문서](https://registry.terraform.io/providers/hashicorp/azurerm)
- [Azure 아키텍처 센터](https://docs.microsoft.com/azure/architecture/)

---

**마지막 업데이트**: 2026-01-19
