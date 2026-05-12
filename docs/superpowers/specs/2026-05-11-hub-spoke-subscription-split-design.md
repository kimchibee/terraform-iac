# Hub/Spoke 2-구독 분리 설계

- 작성일: 2026-05-11
- 대상: `azure/` 폴더 (azure-1/, azure-2/, azure-3/ 변형 폴더는 제외)
- 전제: 현재 어떤 leaf도 `terraform apply` 전 상태이므로 state 마이그레이션 불필요

## 1. 배경과 목적

현재 `azure/` 트리는 hub/spoke 양쪽 리소스가 9개 스택 단일 트리에 섞여 있고, 모든 leaf의 `terraform.tfvars`에 `hub_subscription_id`와 `spoke_subscription_id`가 동일한 단일 구독 ID(`20e3a0f3-...a9911`)로 채워져 있다. 코드 골격(provider alias, variables)은 이미 hub/spoke 분리를 가정하고 있으나 실제 값과 폴더 경계가 통합되어 있다.

본 작업은 hub와 spoke를 **두 개의 별도 Azure 구독**으로 분리하면서 다음 경계를 명확히 한다.

- **폴더 경계**: `azure/hub/`, `azure/spoke/` 두 최상위 트리
- **State 경계**: hub 구독과 spoke 구독 각각에 별도 storage account
- **구독 ID 주입 경계**: tfvars에서 제거하고 환경변수로만 주입

## 2. 목표와 비목표

### 목표
- 61개 leaf를 hub/spoke 양 트리로 물리적으로 재배치한다.
- 각 leaf가 자신의 backend(자신의 구독 storage)와 cross-state 참조(상대 구독 storage)를 모두 다룰 수 있도록 변수 인터페이스를 분리한다.
- 구독 ID는 환경변수 주입으로 전환하여 tfvars에 평문으로 저장하지 않는다.
- AVM 모듈 `source` URL을 외부 GitHub(`kimchibee/terraform-modules`)에서 내부 GitLab(`dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/`)으로 일괄 마이그레이션한다.
- `terraform init -backend=false && terraform validate`가 모든 leaf에서 통과한다.

### 비목표
- `azure-1/`, `azure-2/`, `azure-3/` 변형 폴더는 손대지 않는다.
- 실제 `terraform apply` 실행 및 spoke 구독의 storage account 프로비저닝은 본 작업 범위가 아니다 (운영자가 별도 수행).
- 모듈(`05.ai-services/workload/modules/`)의 내부 코드는 변경하지 않고 위치만 이동한다.
- 신규 기능 추가 없음. 순수 구조 재편.

## 3. 폴더 매핑

### Hub 트리: `azure/hub/`

| 스택 | 포함 leaf |
|---|---|
| `01.network/resource-group/` | `hub-rg` |
| `01.network/vnet/` | `hub-vnet` |
| `01.network/subnet/` | `hub-appgateway-subnet`, `hub-azurefirewall-subnet`, `hub-azurefirewall-management-subnet`, `hub-dnsresolver-inbound-subnet`, `hub-gateway-subnet`, `hub-monitoring-vm-subnet`, `hub-pep-subnet` |
| `01.network/route/` | `hub-route-default` |
| `01.network/public-ip/` | `hub-vpn-gateway` |
| `01.network/virtual-network-gateway/` | `hub-vpn-gateway` |
| `01.network/security-group/application-security-group/` | `keyvault-clients`, `vm-allowed-clients` |
| `01.network/security-group/network-security-group/` | `hub-monitoring-vm`, `hub-pep` |
| `01.network/security-group/network-security-rule/` | `hub-monitoring-vm-allow-keyvault-outbound`, `hub-monitoring-vm-allow-vm-clients-22`, `hub-monitoring-vm-allow-vm-clients-3389`, `hub-pep-allow-keyvault-clients-443`, `hub-pep-allow-keyvault-outbound` |
| `01.network/security-group/security-policy/` | `hub-sg-policy-default` |
| `01.network/security-group/subnet-network-security-group-association/` | `hub-monitoring-vm-subnet`, `hub-pep-subnet` |
| `01.network/dns/dns-private-resolver/` | `hub` |
| `01.network/dns/private-dns-zone/` | `hub-blob`, `hub-vault` |
| `01.network/dns/private-dns-zone-vnet-link/` | `hub-blob-to-hub-vnet`, `hub-openai-to-hub-vnet`, `hub-vault-to-hub-vnet` |
| `02.storage/monitoring/` | `monitoring-storage` |
| `03.shared-services/` | `log-analytics`, `log-analytics-workspace`, `shared`, `shared-services` (미완성 leaf 포함, 그대로 이동) |
| `06.compute/` | `linux-monitoring-vm`, `windows-example` |
| `07.identity/group-membership/` | `admin-core`, `ai-developer-core` (Entra tenant-level, 운영 편의상 hub 배치) |
| `08.rbac/authorization/` | `hub-assignments` |
| `08.rbac/principal/` | `hub-assignments` |
| `08.rbac/group/` | `admin-hub-scope` |
| `09.connectivity/diagnostics/` | `hub` |
| `09.connectivity/peering/` | `hub-to-spoke` |

### Spoke 트리: `azure/spoke/`

| 스택 | 포함 leaf |
|---|---|
| `01.network/resource-group/` | `spoke-rg` |
| `01.network/vnet/` | `spoke-vnet` |
| `01.network/subnet/` | `spoke-apim-subnet`, `spoke-pep-subnet`, `spoke-subnet-nsg` |
| `01.network/route/` | `spoke-route-default` |
| `01.network/security-group/network-security-group/` | `spoke-pep` |
| `01.network/security-group/security-policy/` | `spoke-sg-policy-default` |
| `01.network/security-group/subnet-network-security-group-association/` | `spoke-pep-subnet` |
| `01.network/dns/private-dns-zone/` | `spoke-azure-api`, `spoke-cognitiveservices`, `spoke-ml`, `spoke-notebooks`, `spoke-openai` |
| `01.network/dns/private-dns-zone-vnet-link/` | `spoke-azure-api-to-spoke-vnet`, `spoke-cognitiveservices-to-spoke-vnet`, `spoke-ml-to-spoke-vnet`, `spoke-notebooks-to-spoke-vnet`, `spoke-openai-to-spoke-vnet` |
| `04.apim/workload/` | (그대로) |
| `05.ai-services/workload/` | (그대로, `modules/` 하위 포함) |
| `08.rbac/authorization/` | `spoke-assignments` |
| `08.rbac/principal/` | `spoke-assignments` |
| `08.rbac/group/` | `ai-developer-spoke-scope` |
| `09.connectivity/peering/` | `spoke-to-hub` |

### 정리/제거

- `azure/ci/`, `azure/script/` 빈 폴더 제거 (실제 CI/스크립트는 repo 루트에 위치)

## 4. State 경계 설계

### Storage 분리

| | Hub | Spoke |
|---|---|---|
| 구독 | 기존 hub 구독 | 신규 spoke 구독 (운영자 제공) |
| Storage account | `tfstatea9911` (기존) | 운영자가 별도 생성 (예: `tfstatespoke<suffix>`) |
| Resource group | `terraform-state-rg` (기존) | 운영자 결정 |
| Container | `tfstate` | 운영자 결정 |
| State key 패턴 | `azure/dev/hub/<stack>/<category>/<leaf>/terraform.tfstate` | `azure/dev/spoke/<stack>/<category>/<leaf>/terraform.tfstate` |

`azure/dev/` 접두사는 기존 규약을 유지하고 그 아래에 `hub/` 또는 `spoke/` 한 단계를 추가하는 형태로 통일한다. 폴더 트리와 1:1 대응되어 추적이 단순하다.

### Backend 설정 주입

- 각 leaf에 `backend.hcl.example`을 커밋하고 실제 `backend.hcl`은 `.gitignore`로 제외한다.
- 로컬: `terraform init -backend-config=backend.hcl`
- CI: 파이프라인 job 내에서 heredoc으로 `backend.hcl` 생성 (기존 `azure-2/ci/terraform-base.yml` 패턴 참고)
- `backend.hcl.example` 템플릿: placeholder + hub/spoke 각각 어떤 값을 채워야 하는지 주석 안내 포함

예시 (hub leaf):
```hcl
# Hub leaf — terraform.tfstate는 hub 구독 storage에 저장됨
resource_group_name  = "terraform-state-rg"      # hub 구독의 state RG
storage_account_name = "tfstatea9911"            # hub 구독의 state storage
container_name       = "tfstate"
key                  = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"
use_azuread_auth     = false
```

## 5. 변수 인터페이스 변경

### 5.1 Subscription ID — tfvars에서 제거, 환경변수로만 주입

- 모든 leaf의 `terraform.tfvars`와 `terraform.tfvars.example`에서 `hub_subscription_id`, `spoke_subscription_id` 라인 제거
- `variables.tf`의 두 변수 선언은 유지 (default 없음)
- 주입 방법: `TF_VAR_hub_subscription_id`, `TF_VAR_spoke_subscription_id` 환경변수
- `terraform.tfvars.example` 상단에 환경변수 사용법 주석 추가

### 5.2 Backend 변수 — 단일 세트 → hub/spoke 2세트

기존 단일 세트:
```hcl
variable "backend_resource_group_name"  { type = string }
variable "backend_storage_account_name" { type = string }
variable "backend_container_name"       { type = string }
```

신규 2세트:
```hcl
variable "hub_backend_resource_group_name"    { type = string }
variable "hub_backend_storage_account_name"   { type = string }
variable "hub_backend_container_name"         { type = string }
variable "spoke_backend_resource_group_name"  { type = string }
variable "spoke_backend_storage_account_name" { type = string }
variable "spoke_backend_container_name"       { type = string }
```

이 변수들은 `data.tf`의 `terraform_remote_state` 블록이 참조 대상에 따라 hub 또는 spoke 값을 선택하여 사용한다. **자기 자신의 backend**는 `backend.hcl`로 외부 주입되므로 본 변수와 무관하다.

**값 주입 위치**: cross-state 참조 변수는 각 leaf의 `terraform.tfvars`에 평문으로 채운다 (tfvars는 이미 `.gitignore` 대상이므로 평문 OK). subscription_id와 달리 비밀에 가까운 값이 아니라 storage account 이름 등 운영 식별자라 환경변수까지 끌어올리지 않아도 무방하며, 일관된 backend.hcl 한 파일에서 값을 복사해 채우는 운영 흐름이 직관적이다.

**선언 최소화**: 참조하지 않는 변수는 해당 leaf의 `variables.tf`에서 선언하지 않는다 — leaf별로 hub_*만 / spoke_*만 / 둘 다 중에서 자신의 `data.tf`에 등장하는 remote_state 대상에 따라 자동 결정된다. 예: 자기 자신의 state 외에 어떤 remote_state도 참조하지 않는 leaf는 hub_backend_*/spoke_backend_* 어느 것도 선언하지 않는다.

### 5.3 data.tf 변환 규칙

기존:
```hcl
data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.backend_resource_group_name
    storage_account_name = var.backend_storage_account_name
    container_name       = var.backend_container_name
    key                  = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}
```

신규:
```hcl
data "terraform_remote_state" "hub_rg" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.hub_backend_resource_group_name
    storage_account_name = var.hub_backend_storage_account_name
    container_name       = var.hub_backend_container_name
    key                  = "azure/dev/hub/01.network/resource-group/hub-rg/terraform.tfstate"
  }
}
```

판별 규칙:
- 참조 대상 leaf가 hub 트리로 분류되면 `var.hub_backend_*` + key에 `azure/dev/hub/...` 사용
- 참조 대상 leaf가 spoke 트리로 분류되면 `var.spoke_backend_*` + key에 `azure/dev/spoke/...` 사용

## 6. 변환 절차 (apply 전이라 코드 변경만 수행)

1. `azure/hub/`, `azure/spoke/` 디렉터리 골격 생성
2. 3절 매핑에 따라 `git mv`로 leaf 이동 (61개)
3. `azure/ci/`, `azure/script/` 빈 디렉터리 제거
4. 모든 leaf의 `data.tf`를 5.3절 규칙대로 일괄 변환 (스크립트):
   - state key 경로에 `hub/` 또는 `spoke/` 접두 삽입
   - backend config 변수명을 `hub_backend_*` / `spoke_backend_*`로 교체
5. 모든 leaf의 `variables.tf`에서 기존 `backend_*` 변수 선언을 제거하고, data.tf에 등장하는 참조 대상에 따라 hub/spoke 변수 선언 추가
6. 모든 `terraform.tfvars`, `terraform.tfvars.example` 갱신:
   - 삭제: `hub_subscription_id = ...`, `spoke_subscription_id = ...` (환경변수로 이관)
   - 삭제: 기존 `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name` 라인
   - 추가: 해당 leaf가 참조하는 쪽의 `hub_backend_*` 또는 `spoke_backend_*` 값 (tfvars는 .gitignore이므로 평문 OK). 양쪽 모두 참조하지 않는 leaf는 추가 없음.
7. 모든 `terraform.tfvars.example` 상단에 환경변수 주입 안내 주석 추가
8. 각 leaf에 `backend.hcl.example` 작성 (hub/spoke 트리별 템플릿)
9. `.gitignore`에 `**/backend.hcl` 추가 (이미 있으면 확인)
10. 모든 `main.tf`의 `source = "git::https://github.com/kimchibee/terraform-modules.git//avm/..."` 라인을 9절 매핑표대로 내부 GitLab URL로 일괄 치환
11. 각 leaf에서 `terraform init -backend=false && terraform validate` 실행하여 정합성 검증
12. 작업 PR로 묶어 커밋

## 7. 영향 범위와 위험

- **모든 leaf 일괄 변환**: 자동 변환 스크립트가 필요. 수작업으로는 누락 위험.
- **참조 그래프 일관성**: hub 트리 leaf가 spoke state를 참조하거나 그 반대인 경우(예: `08.rbac/authorization/spoke-assignments`가 hub principal을 참조하는 등)가 있는지 변환 스크립트가 각 data.tf를 leaf별 분류표에 매칭하여 판별해야 한다.
- **CI 파이프라인**: 본 작업은 `azure/`만 변경. `azure-2/`의 GitLab CI 코드는 그대로 두므로 영향 없음. 다만 분리된 구조를 실제로 deploy하려면 추후 CI 파이프라인이 hub/spoke 각각의 backend.hcl을 생성하도록 별도 작업 필요(범위 외).
- **hwanghakbeom 레포 푸시**: 현재 `azure/`만 푸시하는 워크플로이므로 분리 후에도 그대로 동작 (`azure/hub/`, `azure/spoke/` 포함).
- **Private DNS link cross-subscription**: spoke vnet이 hub의 private-resolver를 통해 해석하거나 hub vnet이 spoke zone에 link되는 경우 cross-subscription 권한 필요. apply 단계의 이슈로 본 작업 범위 외.

## 8. 검증 기준

- `azure/hub/` 하위 모든 leaf에서 `terraform init -backend=false && terraform validate` 통과
- `azure/spoke/` 하위 모든 leaf에서 동일하게 통과
- 모든 `terraform.tfvars`에 `subscription_id`, `_subscription_id` 문자열이 등장하지 않음
- 모든 `data.tf`의 state key가 `azure/dev/hub/` 또는 `azure/dev/spoke/` 접두로 시작
- `azure/ci/`, `azure/script/` 디렉터리가 존재하지 않음
- 모든 `main.tf`에 `github.com/kimchibee/terraform-modules` 문자열이 0회 등장
- 모든 `main.tf`의 `source` 라인이 `dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/` 접두를 사용

## 9. 모듈 소스 GitLab 마이그레이션

### 9.1 변환 규칙

```
Before: git::https://github.com/kimchibee/terraform-modules.git//avm/<MODULE>(<VERSION_SUFFIX>?)(<SUBPATH>?)?ref=main
After:  git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/<MODULE_BASE>-main.git(<SUBPATH>?)?ref=main
```

핵심:
- 호스트/그룹 prefix 교체
- 경로 중간 `//avm/` 제거
- 모듈 base 이름 뒤에 버전 접미사(`-v0.7.1`, `-v0.17.1`)가 있으면 제거
- 모듈 base 이름 뒤에 `-main`을 붙이고 `.git` 추가
- submodule 경로(`/modules/<sub>`)는 `.git//modules/<sub>` 형태로 유지
- `?ref=main`은 그대로 유지

### 9.2 매핑표 (17개 고유 GitLab 레포 → 19개 사용 처)

기존 GitHub `//avm/` 이하 경로 → 새 GitLab URL (호스트/그룹 prefix `git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/` 생략)

| 기존 `//avm/` 이하 | 새 (prefix 생략) |
|---|---|
| `terraform-azurerm-avm-res-resources-resourcegroup` | `terraform-azurerm-avm-res-resources-resourcegroup-main.git` |
| `terraform-azurerm-avm-res-network-virtualnetwork-v0.7.1` | `terraform-azurerm-avm-res-network-virtualnetwork-main.git` |
| `terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet` | `terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/subnet` |
| `terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/peering` | `terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/peering` |
| `terraform-azurerm-avm-res-network-routetable` | `terraform-azurerm-avm-res-network-routetable-main.git` |
| `terraform-azurerm-avm-res-network-publicipaddress` | `terraform-azurerm-avm-res-network-publicipaddress-main.git` |
| `terraform-azurerm-avm-ptn-vnetgateway` | `terraform-azurerm-avm-ptn-vnetgateway-main.git` |
| `terraform-azurerm-avm-res-network-applicationsecuritygroup` | `terraform-azurerm-avm-res-network-applicationsecuritygroup-main.git` |
| `terraform-azurerm-avm-res-network-networksecuritygroup` | `terraform-azurerm-avm-res-network-networksecuritygroup-main.git` |
| `terraform-azurerm-avm-res-network-firewallpolicy` | `terraform-azurerm-avm-res-network-firewallpolicy-main.git` |
| `terraform-azurerm-avm-res-network-privatednszone` | `terraform-azurerm-avm-res-network-privatednszone-main.git` |
| `terraform-azurerm-avm-res-network-privatednszone/modules/private_dns_virtual_network_link` | `terraform-azurerm-avm-res-network-privatednszone-main.git//modules/private_dns_virtual_network_link` |
| `terraform-azurerm-avm-res-network-privateendpoint` | `terraform-azurerm-avm-res-network-privateendpoint-main.git` |
| `terraform-azurerm-avm-res-network-dnsresolver` | `terraform-azurerm-avm-res-network-dnsresolver-main.git` |
| `terraform-azurerm-avm-res-storage-storageaccount` | `terraform-azurerm-avm-res-storage-storageaccount-main.git` |
| `terraform-azurerm-avm-res-keyvault-vault` | `terraform-azurerm-avm-res-keyvault-vault-main.git` |
| `terraform-azurerm-avm-res-operationalinsights-workspace` | `terraform-azurerm-avm-res-operationalinsights-workspace-main.git` |
| `terraform-azurerm-avm-res-compute-virtualmachine` | `terraform-azurerm-avm-res-compute-virtualmachine-main.git` |
| `terraform-azurerm-avm-res-apimanagement-service` | `terraform-azurerm-avm-res-apimanagement-service-main.git` |

총 19개 사용 패턴 → 17개 고유 GitLab 레포로 통합 (virtualnetwork 부모+2 submodule, privatednszone 부모+1 submodule).

### 9.3 변환 예시 (전후 비교)

```hcl
# Before
source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-resources-resourcegroup?ref=main"

# After
source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-resources-resourcegroup-main.git?ref=main"
```

```hcl
# Before (submodule)
source = "git::https://github.com/kimchibee/terraform-modules.git//avm/terraform-azurerm-avm-res-network-virtualnetwork-v0.17.1/modules/subnet?ref=main"

# After (submodule)
source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/subnet?ref=main"
```

### 9.4 호환성 (v0.7.1 ↔ v0.17.1 단일화)

기존 코드는 부모 `virtualnetwork`에 `v0.7.1`을, submodule(`subnet`, `peering`)에 `v0.17.1`을 분리 사용했다. GitLab의 `terraform-azurerm-avm-res-network-virtualnetwork-main` 단일 레포가 두 호출 그룹과 모두 호환됨이 운영자에 의해 사전 확인되어, 부모 모듈과 submodule 모두 동일 URL prefix로 매핑한다. 호출부 코드 갱신은 불필요.

- 부모 모듈 호출 leaf: `azure/{hub,spoke}/01.network/vnet/{hub-vnet, spoke-vnet}` 2개
- submodule 호출 leaf: subnet 11개 + peering 2개

`terraform init` + `terraform validate`로 사후 검증은 여전히 수행한다.

### 9.5 인증

- 사용자/CI 환경이 `dev-gitlab.kis.zone`에 git clone 권한을 보유한다고 가정 (SSH 키 또는 GitLab token이 ~/.gitconfig 또는 git credential helper에 구성됨).
- 인증 설정 자체는 본 spec 범위 외 (운영자가 별도 구성).

## 10. 미확정/이후 작업 (범위 외)

- Spoke 구독 ID 실제 값 — 운영자가 환경변수로 제공
- Spoke 구독의 state storage account 생성 — 운영자 별도 수행
- CI 파이프라인 (`azure-2/ci/`)이 hub/spoke 두 backend 생성하도록 갱신 — 별도 작업
- `08.rbac/group/admin-hub-scope`처럼 변수 `admin_group_scope_id`에 hub RG ID가 들어가는 경우, 분리 후에도 동일한 cross-subscription 호환을 보장 (운영 검증 필요)
