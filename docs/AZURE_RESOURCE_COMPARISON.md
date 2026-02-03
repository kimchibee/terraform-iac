# Azure 리소스 비교 가이드

terraform-iac / terraform-modules 두 레포 코드에 **정의된 Azure 리소스**와 **실제 구독에 있는 리소스**를 비교하는 방법입니다.

---

## 1. 코드에 정의된 리소스 (Terraform이 생성·관리 대상)

아래는 **현재 Terraform 코드**가 배포 시 생성하는 Azure 리소스 유형입니다.  
리소스 이름은 `locals.tf`·변수에 따라 `{project_name}-x-x-...` 형태입니다.

### 1.1 루트 main.tf (Role Assignment만 인라인)

| 리소스 유형 | Terraform 주소 | 비고 |
|-------------|----------------|------|
| Role Assignment | `azurerm_role_assignment.vm_storage_access` | VM → Storage |
| Role Assignment | `azurerm_role_assignment.vm_key_vault_access` | VM → Key Vault |
| Role Assignment | `azurerm_role_assignment.vm_key_vault_reader` | VM → Key Vault |
| Role Assignment | `azurerm_role_assignment.vm_storage_reader` | VM → RG Reader |
| Role Assignment | `azurerm_role_assignment.vm_spoke_*` | VM → Spoke 리소스들 |

### 1.2 공통 모듈 (terraform-modules 레포, main.tf에서 참조)

| 모듈 | 리소스 유형 |
|------|-------------|
| log-analytics-workspace | Log Analytics Workspace |
| virtual-machine | Virtual Machine, NIC, OS Disk, (Extension) |
| vnet-peering | Virtual Network Peering (Hub→Spoke 한 방향) |

### 1.3 IaC 모듈 — Hub (modules/dev/hub/)

| 모듈 | 리소스 유형 |
|------|-------------|
| **hub/vnet** | Resource Group, Virtual Network, Subnet, NSG(2), DNS Resolver + Inbound/Outbound Endpoint, DNS Forwarding Ruleset, VNet Link, Private DNS Zone(복수), Private DNS Zone VNet Link, VPN Gateway, Public IP, Local Network Gateway, VPN Connection, Diagnostic Settings(복수) |
| **hub/shared-services** | Log Analytics Solution(Container Insights, Security Insights), Monitor Action Group, Portal Dashboard |
| **hub/monitoring-storage** | Storage Account(모니터링 로그), Private Endpoint(blob), Key Vault, Private Endpoint(key_vault), Role Assignments |

### 1.4 IaC 모듈 — Spoke (modules/dev/spoke/vnet)

| 모듈 | 리소스 유형 |
|------|-------------|
| **spoke/vnet** | Resource Group, Virtual Network, Subnet, NSG(2), NSG Association(2), VNet Peering(Spoke→Hub), Private DNS Zone VNet Link, API Management, Diagnostic Setting(APIM), Cognitive Account(OpenAI), Cognitive Deployment, Private Endpoint(OpenAI), Diagnostic Setting(OpenAI), Storage Account(AI Foundry), Application Insights, Container Registry, Machine Learning Workspace, Private Endpoint(2, AI Foundry) |

### 1.5 리소스 유형 요약 (코드 기준)

| Azure 리소스 유형 | 개수(대략) | 위치 |
|-------------------|------------|------|
| Resource Group | 2 | hub, spoke |
| Virtual Network | 2 | hub, spoke |
| Subnet | 다수 | hub, spoke |
| NSG | 4+ | hub(2), spoke(2) |
| Private DNS Zone | 다수 | hub |
| DNS Resolver 관련 | 4+ | hub |
| VPN Gateway, Public IP, Local Network Gateway, Connection | 4 | hub |
| Key Vault | 1 | hub (monitoring-storage) |
| Storage Account | 2+ | hub(모니터링), spoke(AI Foundry) |
| Log Analytics Workspace | 1 | 공통 모듈 |
| Log Analytics Solution | 2 | shared-services |
| Action Group, Dashboard | 각 1 | shared-services |
| Virtual Machine | 1 | 공통 모듈 (enable 시) |
| VNet Peering | 2 | 공통 모듈(Hub→Spoke) + spoke(Spoke→Hub) |
| API Management | 1 | spoke |
| Azure OpenAI (Cognitive + Deployment) | 2 | spoke |
| AI Foundry (Storage, App Insights, ACR, ML Workspace, PE) | 다수 | spoke |
| Private Endpoint | 다수 | hub, spoke |
| Role Assignment | 다수 | main.tf, monitoring-storage |
| Diagnostic Setting | 다수 | hub, spoke |

---

## 2. 실제 Azure 리소스와 비교하는 방법

### 2.1 Terraform State로 비교 (권장)

이 레포에서 배포했다면 State에 관리 대상 리소스가 들어 있습니다.

```bash
cd /path/to/terraform-config   # terraform-iac 루트
terraform init                 # backend/모듈 준비
terraform state list           # State에 있는 리소스 목록
terraform state list > state-resources.txt
```

- **코드에는 있는데 state에 없음** → 아직 적용 안 됨 또는 리소스 제거됨.
- **state에는 있는데 코드에 없음** → 코드에서 제거된 리소스(apply 시 destroy 대상).

### 2.2 Azure CLI로 구독 리소스 내보내기

실제 구독에 있는 리소스를 파일로 뽑아서 비교할 수 있습니다.

```bash
# 로그인 (이미 되어 있으면 생략)
az login

# 특정 구독 지정 (Hub/Spoke 각각 실행 가능)
az account set --subscription "<hub-subscription-id>"

# 리소스 그룹별 리소스 목록 (테이블)
az resource list --output table > azure-hub-resources.txt

# 리소스 유형·이름만 (비교용)
az resource list --query "[].{type:type, name:name, resourceGroup:resourceGroup}" --output table
```

Spoke 구독도 동일하게 실행한 뒤, `azure-hub-resources.txt`, `azure-spoke-resources.txt`와 위 **1.5 리소스 유형 요약**을 눈으로 비교하면 됩니다.

### 2.3 비교 시 확인할 점

1. **이름 규칙**  
   - 코드: `locals.tf`의 `name_prefix` = `"${var.project_name}-x-x"` → 리소스 이름이 `{project_name}-x-x-...` 형태인지 확인.
2. **리소스 그룹**  
   - Hub 1개, Spoke 1개 (이름에 `-rg`, `-spoke-rg` 등).
3. **코드에만 있는 리소스**  
   - 아직 `terraform apply` 하지 않았거나, 다른 구독/다른 이름으로 배포된 경우.
4. **Azure에만 있는 리소스**  
   - 수동 생성, 다른 IaC, 또는 예전 Terraform에서 만든 뒤 코드에서 빠진 경우 → 필요하면 `terraform import` 검토.

---

## 3. 한 번에 비교 스크립트 예시

아래는 State 목록과 Azure 리소스 목록을 파일로 뽑아 두고, 나중에 비교할 때 쓰는 예시입니다.

```bash
# 1) Terraform state 리스트 (terraform-iac 루트에서)
terraform state list 2>/dev/null | sort > state-list.txt

# 2) Azure 리소스 (구독 2개 사용 시 각각)
az account set --subscription "<hub-subscription-id>"
az resource list --query "[].id" -o tsv | sort > azure-hub-ids.txt

az account set --subscription "<spoke-subscription-id>"
az resource list --query "[].id" -o tsv | sort > azure-spoke-ids.txt

# 3) 비교 (리소스 ID 기준으로는 직접 diff하기 어려우므로, 주로 눈으로 확인)
# state-list.txt ↔ 1.5 리소스 유형 요약
# azure-*-ids.txt ↔ 실제 구독 리소스
```

---

## 4. 정리

| 비교 대상 | 명령/위치 |
|-----------|-----------|
| **코드가 기대하는 리소스** | 이 문서 §1 (정의된 리소스 목록) |
| **Terraform이 관리하는 리소스** | `terraform state list` |
| **실제 Azure에 있는 리소스** | `az resource list` (구독별) |

두 레포(terraform-iac + terraform-modules)의 코드는 §1에 반영되어 있습니다.  
실제 생성된 Azure 리소스와 비교하려면 위 2.1 또는 2.2를 실행한 뒤, 리소스 유형·이름·리소스 그룹을 기준으로 맞춰 보시면 됩니다.
