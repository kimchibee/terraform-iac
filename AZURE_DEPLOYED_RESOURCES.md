# Azure 배포 리소스 아키텍처 및 상세 정보 (Terraform 구조 기반)

## 📋 목차

1. [전체 아키텍처 개요](#전체-아키텍처-개요)
2. [Terraform 모듈 구조 매핑](#terraform-모듈-구조-매핑)
3. [모듈별 리소스 상세](#모듈별-리소스-상세)
4. [루트 레벨 리소스](#루트-레벨-리소스)
5. [네트워크 구성](#네트워크-구성)
6. [보안 및 접근 제어](#보안-및-접근-제어)
7. [리소스 통계](#리소스-통계)

---

## 전체 아키텍처 개요

### Hub-Spoke 네트워크 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hub Subscription                             │
│                    (test-x-x-rg)                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Hub VNet Module                                          │  │
│  │  (modules/networking/hub-vnet)                                  │  │
│  │  ┌─────────────────────────────────────────────────────┐   │  │
│  │  │  Virtual Network: test-x-x-vnet                     │   │  │
│  │  │  Address Space: 10.0.0.0/20                        │   │  │
│  │  │  • VPN Gateway (vpn-gateway.tf)                     │   │  │
│  │  │  • DNS Resolver (dns-resolver.tf)                   │   │  │
│  │  │  • Private DNS Zones (private-dns-zones.tf)         │   │  │
│  │  │  • NSG (main.tf)                                     │   │  │
│  │  └─────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Shared Services Module                                    │  │
│  │  (modules/monitoring/log-analytics)                                     │  │
│  │  • Log Analytics Workspace                                 │  │
│  │  • Solutions (Container Insights, Security Insights)     │  │
│  │  • Action Group                                            │  │
│  │  • Dashboard                                               │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Storage Module                                            │  │
│  │  (modules/storage/monitoring-storage)                                    │  │
│  │  • Key Vault (keyvault.tf)                                │  │
│  │  • Monitoring Storage Accounts (monitoring-storage.tf)   │  │
│  │  • Private Endpoints                                       │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Monitoring VM Module                                      │  │
│  │  (modules/compute/vm-monitoring)                     │  │
│  │  • Virtual Machine: test-x-x-vm                            │  │
│  │  • Network Interface                                       │  │
│  │  • VM Extensions                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                          │
                          │ VNet Peering (main.tf)
                          │
┌─────────────────────────┴─────────────────────────────────────┐
│                  Spoke Subscription                            │
│                  (test-x-x-spoke-rg)                           │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Spoke VNet Module                                         │ │
│  │  (modules/networking/spoke-vnet)                                 │ │
│  │  ┌─────────────────────────────────────────────────────┐ │ │
│  │  │  Virtual Network: test-x-x-spoke-vnet                 │ │ │
│  │  │  Address Space: 10.1.0.0/24                          │ │ │
│  │  │  • API Management (apim.tf)                           │ │ │
│  │  │  • Azure OpenAI (openai.tf)                           │ │ │
│  │  │  • AI Foundry (ai-foundry.tf)                         │ │ │
│  │  │  • VNet Peering (vnet-peering.tf)                     │ │ │
│  │  │  • NSG (main.tf)                                      │ │ │
│  │  └─────────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 모듈 의존성 관계

```
루트 main.tf
    │
    ├──→ module.hub_vnet (modules/networking/hub-vnet)
    │       ├──→ Resource Group 생성
    │       ├──→ Virtual Network
    │       ├──→ Subnets
    │       ├──→ VPN Gateway
    │       ├──→ DNS Resolver
    │       └──→ Private DNS Zones
    │
    ├──→ module.shared_services (modules/monitoring/log-analytics)
    │       └──→ depends_on: [module.hub_vnet]
    │
    ├──→ module.storage (modules/storage/monitoring-storage)
    │       └──→ depends_on: [module.hub_vnet]
    │
    ├──→ module.monitoring_vm (modules/compute/vm-monitoring)
    │       └──→ depends_on: [module.hub_vnet]
    │
    ├──→ module.spoke_vnet (modules/networking/spoke-vnet)
    │       └──→ depends_on: [module.hub_vnet, module.shared_services, module.storage]
    │
    ├──→ azurerm_virtual_network_peering.hub_to_spoke (main.tf)
    │       └──→ depends_on: [module.hub_vnet, module.spoke_vnet]
    │
    └──→ azurerm_role_assignment.* (main.tf)
            └──→ Monitoring VM → Spoke Resources 권한 부여
```

---

## Terraform 모듈 구조 매핑

> **참고**: 최신 Terraform 모듈 구조는 `TERRAFORM_GUIDE.md`를 참조하세요.  
> Terraform 구조와 배포된 인프라 비교는 `INFRASTRUCTURE_COMPARISON.md`를 참조하세요.

---

## 모듈별 리소스 상세

### 1. Hub VNet 모듈 (`modules/networking/hub-vnet`)

#### 모듈 호출 위치
- **루트 파일**: `main.tf` (line 4-44)
- **모듈 경로**: `./modules/networking/hub-vnet`

#### 리소스 그룹
- **파일**: `main.tf` (line 23-27)
- **리소스**: `azurerm_resource_group.hub`
- **이름**: `test-x-x-rg`
- **위치**: Korea Central

#### Virtual Network
- **파일**: `main.tf` (line 32-38)
- **리소스**: `azurerm_virtual_network.hub`
- **이름**: `test-x-x-vnet`
- **주소 공간**: `10.0.0.0/20`

#### 서브넷
- **파일**: `main.tf` (line 43-64)
- **리소스**: `azurerm_subnet.subnets` (for_each)
- **서브넷 목록**:

| 서브넷 이름 | 주소 범위 | 파일 위치 | 용도 |
|------------|----------|----------|------|
| GatewaySubnet | 10.0.0.0/26 | main.tf | VPN Gateway |
| DNSResolver-Inbound | 10.0.0.64/28 | main.tf | DNS Resolver Inbound |
| DNSResolver-Outbound | 10.0.0.80/28 | main.tf | DNS Resolver Outbound |
| Monitoring-VM-Subnet | 10.0.1.0/24 | main.tf | Monitoring VM |
| AzureFirewallSubnet | 10.0.2.0/26 | main.tf | Azure Firewall |
| AzureFirewallManagementSubnet | 10.0.2.64/26 | main.tf | Firewall Management |
| AppGatewaySubnet | 10.0.3.0/24 | main.tf | Application Gateway |
| pep-snet | 10.0.4.0/24 | main.tf | Private Endpoints |

#### Network Security Groups
- **파일**: `main.tf` (line 69-168)
- **리소스**:
  - `azurerm_network_security_group.monitoring_vm` → `test-monitoring-vm-nsg`
  - `azurerm_network_security_group.pep` → `test-pep-nsg`
- **연결**: `azurerm_subnet_network_security_group_association`

#### VPN Gateway
- **파일**: `vpn-gateway.tf`
- **리소스**:
  - `azurerm_public_ip.vpn_gateway` → `test-x-x-vpng-pip`
  - `azurerm_virtual_network_gateway.vpn` → `test-x-x-vpng`
  - `azurerm_local_network_gateway.*` → `test-x-x-lgw-01`
  - `azurerm_virtual_network_gateway_connection.*` → `test-x-x-vcn-1`
- **SKU**: VpnGw1
- **타입**: Vpn

#### DNS Private Resolver
- **파일**: `dns-resolver.tf`
- **리소스**:
  - `azurerm_private_dns_resolver.hub` → `test-x-x-pdr`
  - `azurerm_private_dns_resolver_inbound_endpoint.hub` → `test-x-x-pdr-inbound`
  - `azurerm_private_dns_resolver_outbound_endpoint.hub` → `test-x-x-pdr-outbound`
  - `azurerm_private_dns_resolver_dns_forwarding_ruleset.*` → `test-x-x-pdr-ruleset`

#### Private DNS Zones
- **파일**: `private-dns-zones.tf`
- **리소스**: `azurerm_private_dns_zone.zones` (for_each)
- **DNS Zone 목록** (13개):

| DNS Zone | 용도 |
|----------|------|
| `privatelink.openai.azure.com` | Azure OpenAI |
| `privatelink.monitor.azure.com` | Azure Monitor |
| `privatelink.azure-api.net` | API Management |
| `privatelink.blob.core.windows.net` | Storage Blob |
| `privatelink.vaultcore.azure.net` | Key Vault |
| `privatelink.api.azureml.ms` | Azure ML API |
| `privatelink.queue.core.windows.net` | Storage Queue |
| `privatelink.table.core.windows.net` | Storage Table |
| `privatelink.file.core.windows.net` | Storage File |
| `privatelink.agentsvc.azure-automation.net` | Automation Agent |
| `privatelink.oms.opinsights.azure.com` | Log Analytics OMS |
| `privatelink.ods.opinsights.azure.com` | Log Analytics ODS |
| `privatelink.cognitiveservices.azure.com` | Cognitive Services |
| `privatelink.notebooks.azure.net` | Azure Notebooks |

- **Virtual Network Links**: Hub VNet과 Spoke VNet 모두 연결

#### Diagnostic Settings
- **파일**: `diagnostic-settings.tf`
- **용도**: Hub VNet 리소스의 진단 설정

---

### 2. Shared Services 모듈 (`modules/monitoring/log-analytics`)

#### 모듈 호출 위치
- **루트 파일**: `main.tf` (line 49-73)
- **모듈 경로**: `./modules/monitoring/log-analytics`
- **의존성**: `depends_on = [module.hub_vnet]`

#### Log Analytics Workspace
- **파일**: `main.tf` (line 15-22)
- **리소스**: `azurerm_log_analytics_workspace.main`
- **이름**: `test-x-x-law`
- **SKU**: PerGB2018
- **보존 기간**: 30일

#### Log Analytics Solutions
- **파일**: `main.tf` (line 27-57)
- **리소스**:
  - `azurerm_log_analytics_solution.container_insights` → `ContainerInsights(test-x-x-law)`
  - `azurerm_log_analytics_solution.security_insights` → `SecurityInsights(test-x-x-law)`

#### Action Group
- **파일**: `main.tf` (line 62-75)
- **리소스**: `azurerm_monitor_action_group.main`
- **이름**: `test-action-group`

#### Dashboard
- **파일**: `main.tf` (line 80-122)
- **리소스**: `azurerm_portal_dashboard.main`
- **이름**: `test-dashboard`

---

### 3. Storage 모듈 (`modules/storage/monitoring-storage`)

#### 모듈 호출 위치
- **루트 파일**: `main.tf` (line 78-106)
- **모듈 경로**: `./modules/storage/monitoring-storage`
- **의존성**: `depends_on = [module.hub_vnet]`

#### Key Vault
- **파일**: `keyvault.tf`
- **리소스**: `azurerm_key_vault.hub`
- **이름**: `test-hub-kv`
- **Private Endpoint**: `pe-test-hub-kv` (Storage 모듈에서 생성)

#### Monitoring Storage Accounts
- **파일**: `monitoring-storage.tf`
- **리소스**: `azurerm_storage_account.logs` (for_each)
- **Storage Account 목록** (10개):

| Storage Account | 용도 | Private Endpoint |
|----------------|------|-----------------|
| `testvnetloggf4l` | VNet 로그 | `pe-testvnetlog-blob` |
| `testvpngloggf4l` | VPN Gateway 로그 | `pe-testvpnglog-blob` |
| `testvmloggf4l` | VM 로그 | `pe-testvmlog-blob` |
| `testkvloggf4l` | Key Vault 로그 | `pe-testkvlog-blob` |
| `testapimloggf4l` | API Management 로그 | `pe-testapimlog-blob` |
| `testaoailoggf4l` | Azure OpenAI 로그 | `pe-testaoailog-blob` |
| `testaifloggf4l` | AI Foundry 로그 | `pe-testaiflog-blob` |
| `testacrloggf4l` | Container Registry 로그 | `pe-testacrlog-blob` |
| `testspkvloggf4l` | Spoke Key Vault 로그 | `pe-testspkvlog-blob` |
| `teststgstloggf4l` | Storage 로그 | `pe-teststgstlog-blob` |
| `testnsgloggf4l` | NSG 로그 | `pe-testnsglog-blob` |

- **Private Endpoints**: 각 Storage Account마다 Private Endpoint 생성
- **서브넷**: `pep-snet` (Hub VNet)

---

### 4. Monitoring VM 모듈 (`modules/compute/vm-monitoring`)

#### 모듈 호출 위치
- **루트 파일**: `main.tf` (line 111-131)
- **모듈 경로**: `./modules/compute/vm-monitoring`
- **의존성**: `depends_on = [module.hub_vnet]`
- **Feature Flag**: `var.enable_monitoring_vm`

#### 인스턴스 모듈 구조
- **파일**: `vm-monitoring/main.tf`
- **내용**:
  1. VNet 조회: `data "azurerm_virtual_network" "this"`
  2. 서브넷 조회: `data "azurerm_subnet" "selected"`
  3. 공통 모듈 호출: `module "vm" { source = "../virtual-machine" }`

#### 공통 VM 모듈 (`virtual-machine`)
- **파일**: `virtual-machine/main.tf`
- **리소스**:
  - `azurerm_network_interface.this` → `test-x-x-vm-nic`
  - `azurerm_linux_virtual_machine.this` → `test-x-x-vm`
  - `azurerm_virtual_machine_extension.this` → VM Extensions
- **OS**: Linux (Ubuntu 22.04 LTS)
- **크기**: Standard_B2s
- **서브넷**: Monitoring-VM-Subnet
- **Managed Identity**: System Assigned (활성화)
- **Extensions**:
  - AzureMonitorLinuxAgent
  - enablevmAccess

---

### 5. Spoke VNet 모듈 (`modules/networking/spoke-vnet`)

#### 모듈 호출 위치
- **루트 파일**: `main.tf` (line 194-246)
- **모듈 경로**: `./modules/networking/spoke-vnet`
- **의존성**: `depends_on = [module.hub_vnet, module.shared_services, module.storage]`

#### 리소스 그룹
- **파일**: `main.tf`
- **리소스**: `azurerm_resource_group.spoke`
- **이름**: `test-x-x-spoke-rg`
- **위치**: Korea Central

#### Virtual Network
- **파일**: `main.tf`
- **리소스**: `azurerm_virtual_network.spoke`
- **이름**: `test-x-x-spoke-vnet`
- **주소 공간**: `10.1.0.0/24`

#### 서브넷
- **파일**: `main.tf`
- **리소스**: `azurerm_subnet.subnets` (for_each)
- **서브넷 목록**:

| 서브넷 이름 | 주소 범위 | 용도 |
|------------|----------|------|
| apim-snet | 10.1.0.0/26 | API Management |
| pep-snet | 10.1.0.64/26 | Private Endpoints |

#### Network Security Groups
- **파일**: `main.tf`
- **리소스**:
  - `azurerm_network_security_group.apim` → `test-apim-nsg`
  - `azurerm_network_security_group.pep` → `test-spoke-pep-nsg`

#### API Management
- **파일**: `apim.tf`
- **리소스**: `azurerm_api_management.main`
- **이름**: `test-x-x-apim` (랜덤 suffix 포함)
- **SKU**: Developer_1
- **배포 모드**: Internal (Private)
- **서브넷**: apim-snet
- **Diagnostic Settings**: Log Analytics Workspace로 전송

#### Azure OpenAI
- **파일**: `openai.tf`
- **리소스**: `azurerm_cognitive_account.openai`
- **이름**: `test-x-x-aoai` (랜덤 suffix 포함)
- **SKU**: S0
- **배포 모델**: gpt-4o-mini
- **Private Endpoint**: `pe-test-x-x-aoai`

#### AI Foundry (Azure Machine Learning)
- **파일**: `ai-foundry.tf`
- **리소스**:
  - `azurerm_machine_learning_workspace.ai_foundry` → `test-x-x-aifoundry`
  - `azurerm_storage_account.ai_foundry` → Storage Account
  - `azurerm_container_registry.ai_foundry` → Container Registry
  - `azurerm_key_vault.ai_foundry` → Key Vault (Hub Key Vault 재사용)
  - `azurerm_application_insights.ai_foundry` → Application Insights
  - `azurerm_network_interface.*` → Private Endpoint NICs
  - `azurerm_private_endpoint.*` → Private Endpoints
- **Private Endpoints**:
  - `pe-test-x-x-aifoundry`: ML Workspace
  - `pe-test-x-x-aifoundry-storage`: Storage Account
  - `pe-test-x-x-aifoundry2-kv`: Key Vault

#### VNet Peering (Spoke → Hub)
- **파일**: `vnet-peering.tf`
- **리소스**: `azurerm_virtual_network_peering.spoke_to_hub`
- **설정**: Hub Gateway Transit 사용

---

## 루트 레벨 리소스

### VNet Peering (Hub → Spoke)
- **파일**: `main.tf` (line 252-265)
- **리소스**: `azurerm_virtual_network_peering.hub_to_spoke`
- **이름**: `test-x-x-vnet-to-spoke`
- **설정**:
  - Virtual Network Access: ✅
  - Forwarded Traffic: ✅
  - Gateway Transit: ✅
  - Use Remote Gateways: ❌

### Role Assignments

#### Monitoring VM → Hub Resources
- **파일**: `main.tf` (line 137-189)
- **리소스**:
  - `azurerm_role_assignment.vm_storage_access` → Storage Accounts (Storage Blob Data Contributor)
  - `azurerm_role_assignment.vm_key_vault_access` → Key Vault (Key Vault Secrets User)
  - `azurerm_role_assignment.vm_key_vault_reader` → Key Vault (Key Vault Reader)
  - `azurerm_role_assignment.vm_storage_reader` → Resource Group (Reader)

#### Monitoring VM → Spoke Resources
- **파일**: `main.tf` (line 272-319)
- **리소스**:
  - `azurerm_role_assignment.vm_spoke_key_vault_access` → Spoke Key Vault (Key Vault Secrets User)
  - `azurerm_role_assignment.vm_spoke_storage_access` → Spoke Storage Account (Storage Blob Data Contributor)
  - `azurerm_role_assignment.vm_openai_access` → Azure OpenAI (Cognitive Services User)
  - `azurerm_role_assignment.vm_openai_reader` → Azure OpenAI (Reader)
  - `azurerm_role_assignment.vm_spoke_reader` → Spoke Resource Group (Reader)

---

## 네트워크 구성

### VNet Peering

| Peering | 방향 | 파일 위치 | 리소스 이름 |
|---------|------|----------|------------|
| Hub → Spoke | Hub → Spoke | `main.tf` (line 252) | `test-x-x-vnet-to-spoke` |
| Spoke → Hub | Spoke → Hub | `modules/networking/spoke-vnet/vnet-peering.tf` | Spoke 모듈 내부 |

### DNS 구성

- **Private DNS Zones**: Hub 모듈에서 생성, Spoke VNet에도 연결
- **DNS Resolver**: Hub VNet에 배포, Private DNS 쿼리 해결
- **DNS Forwarding Ruleset**: 온프레미스 DNS 통합

---

## 보안 및 접근 제어

### Network Security Groups

| NSG | 위치 | 파일 | 규칙 |
|-----|------|------|------|
| `test-monitoring-vm-nsg` | Hub VNet | `modules/networking/hub-vnet/main.tf` | SSH (22), RDP (3389), Outbound 허용 |
| `test-pep-nsg` | Hub VNet | `modules/networking/hub-vnet/main.tf` | VNet Inbound 허용 |
| `test-apim-nsg` | Spoke VNet | `modules/networking/spoke-vnet/main.tf` | APIM Management (3443), Load Balancer (6390) |
| `test-spoke-pep-nsg` | Spoke VNet | `modules/networking/spoke-vnet/main.tf` | VNet Inbound 허용 |

### Private Endpoint 전략

모든 주요 서비스는 Private Endpoint를 통해 접근:
- **Storage Accounts**: 11개 Private Endpoints (Storage 모듈)
- **Key Vault**: 1개 Private Endpoint (Storage 모듈)
- **Azure OpenAI**: 1개 Private Endpoint (Spoke 모듈)
- **AI Foundry**: 3개 Private Endpoints (Spoke 모듈)

### Managed Identity

- **Monitoring VM**: System Assigned Managed Identity
- **API Management**: System Assigned Managed Identity
- **역할**: 서비스 간 인증 및 권한 부여

---

## 리소스 통계

### Hub 리소스 그룹 (`test-x-x-rg`)

| 모듈 | 리소스 타입 | 개수 | 파일 위치 |
|------|------------|------|----------|
| Hub VNet | Virtual Networks | 1 | `modules/networking/hub-vnet/main.tf` |
| Hub VNet | Subnets | 8 | `modules/networking/hub-vnet/main.tf` |
| Hub VNet | VPN Gateway | 1 | `modules/networking/hub-vnet/vpn-gateway.tf` |
| Hub VNet | DNS Resolver | 1 | `modules/networking/hub-vnet/dns-resolver.tf` |
| Hub VNet | Private DNS Zones | 13 | `modules/networking/hub-vnet/private-dns-zones.tf` |
| Hub VNet | NSG | 2 | `modules/networking/hub-vnet/main.tf` |
| Shared Services | Log Analytics Workspace | 1 | `modules/monitoring/log-analytics/main.tf` |
| Shared Services | Solutions | 2 | `modules/monitoring/log-analytics/main.tf` |
| Shared Services | Action Group | 1 | `modules/monitoring/log-analytics/main.tf` |
| Shared Services | Dashboard | 1 | `modules/monitoring/log-analytics/main.tf` |
| Storage | Key Vault | 1 | `modules/storage/monitoring-storage/keyvault.tf` |
| Storage | Storage Accounts | 11 | `modules/storage/monitoring-storage/main.tf` |
| Storage | Private Endpoints | 12 | `modules/storage/monitoring-storage/main.tf` |
| Monitoring VM | Virtual Machine | 1 | `modules/compute/vm-monitoring` → `_vm-module` |
| Monitoring VM | Network Interface | 1 | `modules/compute/virtual-machine/main.tf` |
| Monitoring VM | VM Extensions | 2 | `modules/compute/virtual-machine/main.tf` |
| 루트 | VNet Peering | 1 | `main.tf` |
| 루트 | Role Assignments | 4 | `main.tf` |

**총 리소스 수**: 약 111개

### Spoke 리소스 그룹 (`test-x-x-spoke-rg`)

| 모듈 | 리소스 타입 | 개수 | 파일 위치 |
|------|------------|------|----------|
| Spoke VNet | Virtual Networks | 1 | `modules/networking/spoke-vnet/main.tf` |
| Spoke VNet | Subnets | 2 | `modules/networking/spoke-vnet/main.tf` |
| Spoke VNet | NSG | 2 | `modules/networking/spoke-vnet/main.tf` |
| Spoke VNet | API Management | 1 | `modules/networking/spoke-vnet/apim.tf` |
| Spoke VNet | Azure OpenAI | 1 | `modules/networking/spoke-vnet/openai.tf` |
| Spoke VNet | AI Foundry Workspace | 1 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | Storage Accounts | 2 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | Container Registries | 2 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | Key Vaults | 2 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | Application Insights | 2 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | Private Endpoints | 5 | `modules/networking/spoke-vnet/ai-foundry.tf` |
| Spoke VNet | VNet Peering | 1 | `modules/networking/spoke-vnet/vnet-peering.tf` |
| 루트 | Role Assignments | 5 | `main.tf` |

**총 리소스 수**: 약 24개

### 전체 통계

- **총 모듈**: 5개 (Hub VNet, Shared Services, Storage, Monitoring VM, Spoke VNet)
- **총 리소스 그룹**: 2개
- **총 Virtual Networks**: 2개
- **총 서브넷**: 10개 (Hub: 8개, Spoke: 2개)
- **총 Private DNS Zones**: 13개
- **총 Storage Accounts**: 13개 (Hub: 11개, Spoke: 2개)
- **총 Private Endpoints**: 17개 (Hub: 12개, Spoke: 5개)
- **총 Key Vaults**: 3개 (Hub: 1개, Spoke: 2개)
- **총 Virtual Machines**: 1개

---

## 주요 특징

### 1. 모듈화된 구조
- 각 기능별로 모듈 분리
- 재사용 가능한 구조
- 명확한 의존성 관리

### 2. 중앙 집중식 모니터링
- 모든 리소스의 로그가 Hub의 중앙 Storage Account로 수집
- Log Analytics Workspace를 통한 통합 분석
- Monitoring VM을 통한 중앙 집중식 로그 수집

### 3. Private Endpoint 전략
- 모든 주요 서비스는 Private Endpoint를 통해 접근
- Public 인터넷 노출 최소화
- 네트워크 격리 및 보안 강화

### 4. Hub-Spoke 아키텍처
- Hub: 중앙 집중식 네트워크 및 보안 서비스
- Spoke: 워크로드 실행 환경
- VNet Peering을 통한 안전한 연결

### 5. 보안 강화
- NSG를 통한 네트워크 트래픽 제어
- Managed Identity를 통한 서비스 간 인증
- Role-Based Access Control (RBAC) 적용

---

## 파일별 리소스 매핑 요약

| Terraform 파일 | 배포된 리소스 | 개수 |
|---------------|-------------|------|
| `main.tf` (루트) | VNet Peering, Role Assignments | 10 |
| `modules/networking/hub-vnet/main.tf` | Resource Group, VNet, Subnets, NSG | 12 |
| `modules/networking/hub-vnet/vpn-gateway.tf` | VPN Gateway, Public IP, Connections | 4 |
| `modules/networking/hub-vnet/dns-resolver.tf` | DNS Resolver, Endpoints, Ruleset | 4 |
| `modules/networking/hub-vnet/private-dns-zones.tf` | Private DNS Zones, Links | 26 |
| `modules/monitoring/log-analytics/main.tf` | Log Analytics, Solutions, Action Group, Dashboard | 5 |
| `modules/storage/monitoring-storage/keyvault.tf` | Key Vault, Private Endpoint | 2 |
| `modules/storage/monitoring-storage/main.tf` | Storage Accounts, Private Endpoints | 22 |
| `modules/compute/vm-monitoring/main.tf` | Data Sources (VNet, Subnet) | 2 |
| `modules/compute/virtual-machine/main.tf` | VM, NIC, Disk, Extensions | 5 |
| `modules/networking/spoke-vnet/main.tf` | Resource Group, VNet, Subnets, NSG | 6 |
| `modules/networking/spoke-vnet/apim.tf` | API Management, Diagnostic Settings | 2 |
| `modules/networking/spoke-vnet/openai.tf` | Azure OpenAI, Private Endpoint | 2 |
| `modules/networking/spoke-vnet/ai-foundry.tf` | ML Workspace, Storage, ACR, Key Vault, App Insights, Private Endpoints | 12 |
| `modules/networking/spoke-vnet/vnet-peering.tf` | VNet Peering | 1 |

---

**마지막 업데이트**: 2026-01-19  
**환경**: test  
**위치**: Korea Central  
**Terraform 버전**: ~> 1.5
