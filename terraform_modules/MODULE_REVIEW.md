# terraform_modules 추가 모듈 검토

기존 프로젝트(`modules/`, `main.tf`, `INFRASTRUCTURE_COMPARISON.md`)에서 사용 중인 Azure 리소스를 기준으로, **vnet / storage-account 외에 공통 모듈로 두면 좋은 항목**을 검토한 결과입니다.

---

## 0. 설계 원칙: 스케일 아웃 vs 단일/SaaS

| 구분 | terraform_modules (공통 모듈) | terraform_iac (루트/환경별) |
|------|------------------------------|-----------------------------|
| **대상** | **스케일 아웃되는 리소스** — 여러 개·여러 환경에서 반복 생성되는 패턴 | **단일 리소스** — 환경당 1개 또는 SaaS/비즈니스 서비스 |
| **예시** | Resource Group, VNet, Subnet, Storage Account, Key Vault, Private Endpoint, NSG, Diagnostic Settings, (선택) Log Analytics Workspace, VM | VPN Gateway, DNS Resolver, API Management, Azure OpenAI, AI Foundry, Dashboard, Action Group 등 |
| **이유** | 동일한 인터페이스로 여러 번 호출 가능 → 코드 공통화·일관성·버전 관리 이점 | 환경·고객별로 SKU·설정·조합이 달라 “한 모듈 한 역할”로 자르기 어렵고, 루트에서 직접 관리하는 편이 변경 영향이 명확함 |

**정리**: 리소스가 **스케일 아웃**(여러 개·반복)되는 것은 terraform_modules로, **단일/SaaS**처럼 환경당 하나이거나 비즈니스 서비스는 terraform_iac에서 관리하는 구조를 권장합니다.

---

## 1. 현재 사용 중인 Azure 리소스 요약

| 리소스 타입 | 사용처 | 개수/용도 |
|-------------|--------|-----------|
| Resource Group | Hub, Spoke | 환경별 RG → ✅ **resource-group 모듈** |
| Virtual Network + Subnets | Hub, Spoke | ✅ **vnet 모듈로 보유** |
| Storage Account | Hub(11), Spoke(2) | 로그/모니터링, AI Foundry | ✅ **storage-account 모듈로 보유** |
| Key Vault | Hub(1), Spoke(2) | 시크릿, AI Foundry → ✅ **key-vault 모듈** |
| Log Analytics Workspace | Hub | Shared, Solutions/AG/Dashboard 포함 |
| Private DNS Zones | Hub(13) | Storage/KV/OpenAI/APIM/ML 등 |
| Private Endpoints | Hub(12), Spoke(5) | Storage, KV, OpenAI 등 → ✅ **private-endpoint 모듈** |
| VNet Peering | Hub↔Spoke | 양방향 각 1개 |
| NSG | Hub(2), Spoke(2) | 서브넷별 |
| Diagnostic Settings | 다수 리소스 | VNet, Storage, KV, NSG, VPN Gateway 등 |
| Virtual Machine | Hub(1) | Monitoring VM (Linux) |
| VPN Gateway, DNS Resolver | Hub | 온프레미스/연결 |
| API Management, Azure OpenAI, AI Foundry | Spoke | 비즈니스 서비스 |

---

## 2. 추가 모듈 권장 여부 (우선순위)

### 2.1 우선 추가 모듈 (✅ 생성 완료)

| 모듈명 | 단일 책임 | 재사용성 | 상태 |
|--------|-----------|----------|------|
| **resource-group** | Resource Group 1개 생성 | 매우 높음 | ✅ **생성됨** |
| **key-vault** | Key Vault 1개 + sku/soft_delete/network_acls 등 기본 설정 | 높음 | ✅ **생성됨** (PE는 private-endpoint 모듈 사용) |
| **private-endpoint** | 특정 리소스에 대한 Private Endpoint 1개 + (선택) Private DNS Zone 연결 | 매우 높음 | ✅ **생성됨** |

이 세 가지는 **스케일 아웃되는 패턴**(여러 RG, 여러 KV, 여러 PE)에 맞아 terraform_modules에 두고, terraform_iac에서는 `ref=<태그>`로만 참조하면 됩니다.

---

### 2.2 컨설턴트 권장: 추가 시 이점이 있는 모듈 (스케일 아웃 관점)

**스케일 아웃되는 리소스**만 공통 모듈로 둔다는 기준으로 보면, 아래도 terraform_modules 후보입니다.

| 모듈명 | 단일 책임 | 스케일 아웃 여부 | 비고 |
|--------|-----------|------------------|------|
| **log-analytics-workspace** | Log Analytics Workspace 1개만 생성 | △ (환경당 1개일 수 있음) | 여러 프로젝트/환경에서 동일 패턴이면 공통화 가치 있음. Solutions/AG/Dashboard는 **단일/비즈니스**에 가까우므로 terraform_iac 권장. |
| **vnet-peering** | 한 방향 VNet Peering 1개 | ✅ (Hub↔Spoke, 다중 Spoke 시 반복) | Spoke가 늘어나면 PEering 쌍이 늘어남. 옵션만 변수로 노출하면 재사용 가능. |
| **nsg** | NSG 1개 + security_rule (동적) | ✅ (서브넷마다 NSG) | Hub 2개, Spoke 2개 등 서브넷별 NSG가 반복. 규칙을 변수(리스트/맵)로 받으면 단일 책임 유지. |
| **diagnostic-settings** | 특정 리소스 1개에 대한 Monitor Diagnostic Setting 1건 | ✅ (리소스마다 1개씩 반복) | VNet, Storage, KV, NSG, VPN Gateway 등 **대상만 바꿔서** 반복 호출. log/metric 카테고리는 변수로. |
| **private-dns-zone** | Private DNS Zone 1개 + (선택) VNet Link 1개 | ✅ (Zone 13개, 링크 다수) | Zone 이름/리소스 그룹만 받고, 링크는 선택 변수. “zone 1개 단위”로 재사용. |
| **virtual-machine** | Linux/Windows VM 1대 (NIC, OS 디스크, 확장) | △ (VM 수가 많아지면 스케일 아웃) | Monitoring VM 1대만 있으면 단일에 가깝고 terraform_iac에서 관리해도 됨. VM 수가 늘어나면 terraform_modules로 올리는 것 권장. |

**권장 순서**:  
1) **diagnostic-settings**, **nsg** — 리소스 개수만큼 반복 호출되므로 공통 모듈화 이득이 큼.  
2) **private-dns-zone**, **vnet-peering** — Zone/Peering 수가 늘어나는 구조라면 추가.  
3) **log-analytics-workspace**, **virtual-machine** — “여러 환경·여러 개” 패턴이 확실해지면 추가.

---

### 2.3 단일/SaaS → terraform_iac에서 관리 (공통 모듈 비권장)

| 리소스/구성 | 이유 |
|-------------|------|
| **VPN Gateway** | Hub 전용 1개, 로컬 게이트웨이/연결 설정 등 환경·고객별 차이 큼. **단일 리소스**이므로 terraform_iac(또는 기존 hub 모듈)에 두는 것이 적합. |
| **DNS Private Resolver** | Hub 중심 1개, 인바운드/아웃바운드·ruleset 등 설정이 복잡. **단일**에 가깝고 환경별 커스터마이징 비중이 큼. |
| **API Management / Azure OpenAI / AI Foundry** | 환경당 1개 또는 비즈니스 서비스 단위. SKU·네트워크·PE·진단 조합이 서비스마다 다름. **SaaS/단일**이므로 terraform_iac 또는 spoke 전용 모듈에서 관리 권장. |
| **Action Group, Dashboard, Log Analytics Solutions** | 모니터링/비즈니스 설정에 가깝고, 환경당 1세트인 경우가 많음. **단일**에 가깝게 두고 terraform_iac에서 관리. |

---

## 3. 정리 및 권장 순서

- **terraform_modules (스케일 아웃·재사용)**  
  - **보유**: `vnet`, `storage-account`  
  - **추가 완료**: `resource-group`, `key-vault`, `private-endpoint`  
  - **선택 추가**: `diagnostic-settings`, `nsg` → `private-dns-zone`, `vnet-peering` → `log-analytics-workspace`, `virtual-machine` (패턴이 늘어나면)

- **terraform_iac (단일/SaaS)**  
  - VPN Gateway, DNS Resolver, API Management, Azure OpenAI, AI Foundry, Action Group, Dashboard 등은 terraform_iac 또는 도메인별 모듈에서 관리.

**정리**: 리소스가 **스케일 아웃**되면 terraform_modules, **단일/SaaS**면 terraform_iac로 두는 기준을 유지하면, 변경 영향이 예측 가능하고 장기 운영에 유리합니다.
