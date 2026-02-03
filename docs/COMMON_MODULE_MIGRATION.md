# 공통 모듈 vs IaC 분리 설계

**목표**: 공통 모듈(terraform-modules)과 IaC(terraform-iac) 두 가지만으로 관리.  
IaC 루트는 **공통 모듈만 호출**하고, 환경 전용/복합 리소스는 IaC 쪽에만 둡니다.

---

## 1. 현재 구조 vs 목표 구조

### 현재 (terraform-iac 루트)

- **main.tf** → `./modules/networking/hub-vnet`, `./modules/monitoring/log-analytics`, `./modules/storage/monitoring-storage`, `./modules/compute/vm-monitoring`, `./modules/networking/spoke-vnet` 등 **로컬 모듈** 호출
- **modules/** 아래에 Hub/Spoke/Storage/APIM/OpenAI 등 **복합 모듈**이 많이 있음

### 목표

- **공통 모듈 (terraform-modules 레포)**: 단일 책임, 재사용 가능한 **빌딩 블록**만
- **IaC (terraform-iac)**: 루트 **main.tf** 등에서 **공통 모듈(git 소스)만** 호출 + 필요한 경우 **루트에 인라인 리소스** 또는 **소수의 IaC 전용 조합**

---

## 2. 공통 모듈로 옮길 수 있는 것 vs IaC에만 둘 것

### 2.1 이미 공통 모듈(terraform-modules)에 있는 것

| 공통 모듈 | 역할 | IaC에서 사용 예 |
|-----------|------|-----------------|
| **resource-group** | RG 1개 | Hub RG, Spoke RG |
| **vnet** | VNet + 서브넷 | Hub VNet, Spoke VNet |
| **storage-account** | Storage Account 1개 | 로그용 스토리지 여러 개 |
| **key-vault** | Key Vault 1개 | Hub KV, Spoke KV |
| **private-endpoint** | PE 1개 + DNS 연결 | Storage/KV/OpenAI 등 PE |

→ **지금도 main.tf에서 이 소스만 쓰도록** 바꾸면, “공통 모듈 + IaC” 구조에 맞습니다.

### 2.2 공통 모듈로 추가하면 좋은 것 (단일 책임)

현재 `./modules/` 안에 있지만 **한 가지 역할만** 하도록 잘라서 공통 모듈로 둘 수 있는 것들입니다.

| 현재 위치 | 공통 모듈 후보 | 역할 | 비고 |
|-----------|----------------|------|------|
| monitoring/log-analytics | **log-analytics-workspace** | Workspace 1개만 | Solutions/AG/Dashboard는 IaC 또는 별도 모듈 |
| hub-vnet, spoke-vnet 내 NSG | **nsg** | NSG 1개 + 규칙 | 서브넷마다 반복 |
| hub-vnet 등 diagnostic-settings | **diagnostic-settings** | 리소스 1개당 진단 설정 1건 | VNet/Storage/KV 등 공통 |
| spoke-vnet/vnet-peering, 루트 Peering | **vnet-peering** | 한 방향 Peering 1개 | Hub↔Spoke |
| hub-vnet/private-dns-zones | **private-dns-zone** | Zone 1개 + (선택) VNet Link | Zone 13개 등 반복 |
| compute/vm-monitoring, virtual-machine | **virtual-machine** | Linux/Windows VM 1대 | Monitoring VM 등 |

→ 위는 **terraform-modules 레포에 새 모듈로 추가**하고, IaC의 main.tf에서는 `source = "git::...terraform-modules...//terraform_modules/모듈명?ref=..."` 만 쓰면 됩니다.

### 2.3 IaC에만 두는 것 (공통 모듈로 안 옮기는 것)

환경/구성에 따라 달라지거나, 한 번에 여러 리소스를 묶는 **조합**에 가까운 것들입니다.

| 리소스/기능 | 이유 |
|-------------|------|
| **VPN Gateway** | Hub 1개, 로컬 게이트웨이/연결 설정 등 환경별 차이 큼 |
| **DNS Private Resolver** | Hub 1개, 인바운드/아웃바운드·ruleset 등 설정 복잡 |
| **API Management** | SKU·VNet·정책 조합이 환경별로 다름 |
| **Azure OpenAI** | 배포/모델 설정이 환경·비즈니스마다 다름 |
| **AI Foundry (ML Workspace 등)** | 워크스페이스·스토리지·ACR 조합, 환경 전용 |
| **Log Analytics Solutions / Action Group / Dashboard** | 모니터링/비즈니스 설정, 환경당 1세트에 가까움 |

→ 이건 **IaC 루트의 main.tf** 에서 `resource "azurerm_..."` 로 직접 쓰거나, **IaC 전용으로만 쓰는 작은 모듈**(예: `terraform_iac/hub/vpn-gateway.tf` 같은 식)으로 두는 편이 맞습니다. **공통 모듈 레포에는 넣지 않습니다.**

---

## 3. 목표 구조 요약

### 공통 모듈 (terraform-modules 레포)

- **이미 있음**: resource-group, vnet, storage-account, key-vault, private-endpoint  
- **추가 권장**: log-analytics-workspace, nsg, diagnostic-settings, vnet-peering, private-dns-zone, virtual-machine  
- **역할**: “리소스 1종 1개” 수준의 빌딩 블록만. 환경(dev/stage/prod)은 변수로만 받음.

### IaC (terraform-iac)

- **루트 .tf**: main.tf, variables.tf, provider.tf, terraform.tf, outputs.tf, locals.tf, data.tf  
- **main.tf**:  
  - 가능한 부분은 전부 **공통 모듈** 호출: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/xxx?ref=v1.0.0"`  
  - VPN Gateway, DNS Resolver, APIM, OpenAI, AI Foundry, Solutions/AG/Dashboard 등은 **루트 인라인** 또는 **IaC 전용 소수 모듈**만 사용  
- **modules/**:  
  - **최종 목표**: 제거하거나, “공통 모듈로 안 옮기는 조합”만 최소한으로 유지 (예: `terraform_iac/hub/`, `terraform_iac/spoke/` 에서 VPN/DNS/APIM 등만)

---

## 4. 단계별 이전 순서 (권장)

1. **terraform-modules에 공통 모듈 추가**  
   - log-analytics-workspace, nsg, diagnostic-settings, vnet-peering, private-dns-zone, virtual-machine 중 필요한 것부터 추가.  
   - 버전 태그(ex: v1.0.0) 붙여서 배포.

2. **IaC main.tf에서 공통 모듈로 교체**  
   - Hub RG/VNet/서브넷 → terraform-modules **resource-group**, **vnet**  
   - Storage/Key Vault/PE → terraform-modules **storage-account**, **key-vault**, **private-endpoint**  
   - Log Analytics Workspace → terraform-modules **log-analytics-workspace** (추가 후)  
   - 기타 NSG, 진단, Peering, Private DNS Zone, VM → 해당 공통 모듈로 교체.

3. **로컬 modules/ 정리**  
   - 위에서 공통 모듈로 대체한 부분은 **modules/** 에서 제거.  
   - VPN Gateway, DNS Resolver, APIM, OpenAI, AI Foundry 등은 **main.tf 인라인** 또는 **terraform_iac/ 아래 소수 파일**로만 유지.

4. **검증**  
   - `terraform plan` 으로 리소스 변경 최소화 확인.  
   - 필요 시 `terraform state mv` 로 기존 리소스 주소만 정리.

---

## 5. 정리

- **공통 모듈로 관리할 수 있는 것**:  
  - 이미 있는 5종 + **log-analytics-workspace, nsg, diagnostic-settings, vnet-peering, private-dns-zone, virtual-machine**  
  → 이렇게 하면 “공통 모듈”과 “IaC” 두 가지로만 나눌 수 있습니다.
- **IaC에만 두는 것**:  
  - VPN Gateway, DNS Resolver, APIM, OpenAI, AI Foundry, Solutions/AG/Dashboard 등 **환경·비즈니스 전용** 리소스.  
  - 이건 IaC 루트 또는 IaC 전용 소수 모듈에서만 관리하면 됩니다.

이 설계대로 진행하면 **공통 모듈(terraform-modules) + IaC(terraform-iac)** 만으로 분리 관리할 수 있습니다.

---

## 6. 루트 모듈은 IaC 레포에서, 공통 모듈은 프로젝트 간 공유

### 루트 모듈 = IaC 레포에서 관리

- **루트 모듈**(main.tf, variables.tf, outputs.tf, provider.tf, terraform.tf, locals.tf, data.tf)은 **배포의 진입점**이므로 **IaC 레포(terraform-iac)** 에서 관리하는 것이 맞습니다.
- IaC 레포 = “이 프로젝트/이 환경을 어떻게 배포할지”에 대한 설정.  
  구독, 리소스 그룹명, VNet 주소, 기능 플래그 등은 **프로젝트·환경마다 다르기 때문**에 루트는 IaC 쪽에 두는 게 자연스럽습니다.

### 나중에 다른 Azure 프로젝트가 생기면 — 공통 모듈을 같이 쓰기

- **현재 배포된 시스템과 관계 있는 다른 Azure 프로젝트**가 생기면:
  - **새 프로젝트용 IaC**를 만듭니다.  
    → 새 레포(예: `terraform-iac-project-b`) 또는 같은 IaC 레포 안에 **새 루트**(예: `environments/project-b/`)를 두는 방식.
  - 그 **새 IaC 루트**에서 **같은 공통 모듈(terraform-modules) 레포**를 참조합니다.  
    → `source = "git::https://github.com/.../terraform-modules.git//terraform_modules/xxx?ref=v1.0.0"` 형태로 그대로 사용.

이렇게 하면:

| 구분 | 관리 위치 | 여러 프로젝트에서 |
|------|-----------|-------------------|
| **루트 모듈** | IaC 레포 (프로젝트/환경별) | 프로젝트마다 **루트 1세트** (각자 variables·provider·리소스 구성) |
| **공통 모듈** | terraform-modules 레포 (한 곳) | **같은 공통 모듈**을 여러 IaC에서 `git::...?ref=태그` 로 참조 |

- **공통 모듈**을 한 레포에서만 관리하므로, 버그 수정·개선을 반영하면 **그 공통 모듈을 쓰는 모든 Azure 프로젝트**에서 동일한 품질을 유지할 수 있습니다.
- **프로젝트별 차이**(구독, 네이밍, 기능 on/off)는 **각 IaC 루트의 variables·locals·모듈 호출 인자**에서만 다르게 두면 됩니다.

정리하면, **루트 모듈은 IaC 레포에서 관리**하고, **다른 Azure 프로젝트가 생기면 새 IaC(새 레포 또는 새 루트)를 만들고 같은 공통 모듈 레포를 참조해 같이 쓰는 구조**가 좋습니다.
