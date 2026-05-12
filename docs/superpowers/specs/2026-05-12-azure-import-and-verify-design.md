# Azure 환경 Import & Variable 검증 설계

작성일: 2026-05-12
대상 브랜치: `feat/hub-spoke-subscription-split` (또는 후속 브랜치)
대상 폴더: `azure/`

## 1. 배경과 목표

### 1.1 배경

`azure/` 트리에는 Hub/Spoke 9개 스택, 약 61개 leaf의 Terraform 코드가 이미 작성되어 있다.
- 코드 골격: `azure/hub/` (37 leaves), `azure/spoke/` (24 leaves)
- 각 leaf는 `main.tf`, `provider.tf`, `backend.tf`, `variables.tf`, `locals.tf`, `data.tf`, `outputs.tf`, `terraform.tfvars(.example)` 구성
- 모듈 소스: `git::https://github.com/kimchibee/terraform-modules.git//avm/...` 또는 내부 GitLab의 AVM 사본
- Backend: Azure Storage Account `tfstatea9911` (RG `terraform-state-rg`, 컨테이너 `tfstate`) — 수동 생성 완료

한편 Azure 구독 `20e3a0f3-f1af-4cc5-8092-dc9b276a9911`에는 동일한 9개 스택의 리소스가 이미 다른 경로(수동/타 Terraform)로 배포되어 운영 중이다.

### 1.2 목표

1. 운영 중인 Azure 리소스를 **현재 `azure/` 코드의 Terraform state로 import**한다.
2. Import 직후 모든 leaf에서 `terraform plan`이 **`0 to add, 0 to change, 0 to destroy`** 가 되도록 코드/변수를 정합한다.
3. Import 완료 후 **변수(tfvars) 변경 → plan → apply** 흐름이 실제 Azure 리소스에 의도대로 반영되는지 검증한다.

### 1.3 비목표

- 신규 리소스 생성, 아키텍처 변경
- bootstrap/prepare 단계 부활 (사용하지 않기로 기결정)
- GitLab CI 파이프라인에서의 import 자동화 (로컬/엔지니어 수동 실행 전제, 후속 작업)
- hub/spoke 구독 실제 분리 (현재 spec 범위 외, [[hub-spoke-subscription-split-design]] 참조)

## 2. 작업 환경 전제

| 항목 | 값 |
|---|---|
| Terraform 버전 | v1.14.6 (≥ 1.5 이므로 `import { ... }` 블록 사용 가능) |
| 대상 폴더 | `azure/` |
| 레이아웃 | `azure/hub/<stack>/<leaf>`, `azure/spoke/<stack>/<leaf>` (≈ 61 leaves) |
| 인증 방식 | `az login` (로컬), `ARM_*` 환경변수 (필요 시) |
| 구독 ID | 단일 구독 `20e3a0f3-f1af-4cc5-8092-dc9b276a9911` (hub/spoke 동일) |
| State Backend | Storage Account `tfstatea9911`, 컨테이너 `tfstate` |
| State key 규칙 | `azure/dev/<stack>/<leaf>/terraform.tfstate` |
| Cross-leaf 참조 | `data.terraform_remote_state.<name>` (의존 leaf의 state를 읽음) |

## 3. 전체 워크플로우

```
Phase 0  사전 준비 (인증, 인벤토리, 도구 확인)
   ↓
Phase 1  Pilot 1 leaf로 절차 검증 (hub/01.network/resource-group/hub-rg)
   ↓
Phase 2  스택별 대표 leaf 9개로 import 주소 패턴 카탈로그 확정
   ↓
Phase 3  나머지 leaf (~51개) 스크립트로 일괄 import
   ↓
Phase 4  Variable 변경 시나리오로 plan/apply 검증 (tag → SKU → CIDR)
```

각 Phase 종료 시 **검증 게이트**를 통과해야 다음 Phase로 진행한다 (§ 8 참조).

## 4. Phase 상세

### 4.1 Phase 0 — 사전 준비

**산출물**
- `docs/import/inventory.csv` — Azure 리소스 인벤토리 (resource_id, type, rg, name)
- `docs/import/leaf-to-resource-map.csv` — leaf 경로 ↔ Terraform 주소 ↔ Azure resource_id 매핑

**작업**

1. **인증 및 권한 확인**
   - `az login`, `az account set --subscription "20e3a0f3-..."`
   - state SA에 대한 Storage Blob Data Contributor 권한 확인
2. **인벤토리 추출**
   - `az resource list --subscription "$SUB" -o json > inventory.json`
   - 스택별 리소스 그룹 기준으로 그룹화: `test-x-x-rg`, `test-x-x-spoke-rg`, …
3. **leaf 매핑 초안 작성**
   - `find azure -name main.tf`로 leaf 경로 나열
   - 각 leaf의 `main.tf`에서 `module ... { name = local.xxx }`를 읽어 예상 리소스명 추출
   - CSV로 leaf ↔ azure resource_id 매핑 (수동 검토 필수)
4. **도구 준비**
   - `terraform` v1.14.6
   - `jq`, `yq` (인벤토리 가공)
   - 본 spec과 같은 디렉토리에 `scripts/import/` 작업 영역 확보

### 4.2 Phase 1 — Pilot

**대상 leaf**: `azure/hub/01.network/resource-group/hub-rg`
**선정 이유**: 의존성 없는 최상위 leaf, 모듈 1단 구조, 실패해도 영향 작음

**절차** (이후 Phase 1~3 모든 leaf에 반복 적용)

```
1) backend.tf의 key 라인 주석 해제
   key = "azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"

2) terraform init
   (-backend-config로 storage account, container, RG 주입)

3) Azure 리소스 ID 확보
   az group show --name test-x-x-rg --query id -o tsv

4) imports.tf 작성
   import {
     id = "/subscriptions/.../resourceGroups/test-x-x-rg"
     to = module.resource_group.azurerm_resource_group.this
   }

5) terraform plan
   - 기대: "Plan: 1 to import, 0 to add, 0 to change, 0 to destroy."
   - diff 발생 시 §6 조정 절차

6) terraform apply
   - state에 import만 반영, 실제 리소스 무변경

7) imports.tf 삭제 후 terraform plan 재실행
   - "No changes." 확인 (sanity check)

8) leaf 작업 로그 작성 (resource_id, 적용 시각, plan 출력 요약)
```

**검증 게이트**
- 위 8단계가 한 leaf에서 끝까지 완료
- `terraform state list`에 import된 주소가 보임
- 절차 중 발견된 함정/예외를 spec의 §6 또는 §7에 반영

### 4.3 Phase 2 — 스택별 대표 leaf (Import 주소 카탈로그)

**대상**: 각 스택에서 1개씩 총 9개 leaf

| 스택 | 대표 leaf | 패턴 |
|---|---|---|
| 01.network | `vnet/hub-vnet` | AVM VNet (중첩 모듈) |
| 02.storage | `monitoring/<leaf>` | Storage Account |
| 03.shared-services | `log-analytics-workspace/<leaf>` | Log Analytics |
| 04.apim | `workload` | APIM |
| 05.ai-services | `workload` | AI Services |
| 06.compute | `linux-monitoring-vm` | VM + NIC + Disk (복합) |
| 07.identity | `group-membership` | Azure AD (provider 다름) |
| 08.rbac | `authorization` | Role Assignment |
| 09.connectivity | `peering` | VNet Peering (cross-state 참조) |

**산출물**: `docs/import/address-catalog.md`

각 패턴별로 다음을 기록:

```hcl
# 패턴 A: 단일 리소스 모듈 (resource-group)
to = module.resource_group.azurerm_resource_group.this

# 패턴 B: AVM 중첩 — VNet
to = module.hub_vnet.azurerm_virtual_network.vnet[0]

# 패턴 C: for_each 모듈 — subnet
to = module.subnets["app-subnet"].azurerm_subnet.this[0]

# 패턴 D: VM 복합 (NIC, OS Disk, Data Disk 각각 import)
to = module.linux_vm.azurerm_linux_virtual_machine.this[0]
to = module.linux_vm.azurerm_network_interface.this[0]
to = module.linux_vm.azurerm_managed_disk.this["data0"]

# 패턴 E: cross-state 의존 (peering)
to = module.hub_to_spoke_peering.azurerm_virtual_network_peering.this[0]
```

**검증 게이트**
- 9개 대표 leaf 모두 plan no-diff
- 카탈로그가 leaf 분류 기준(모듈 깊이, for_each 여부, 복합 리소스)을 모두 커버

### 4.4 Phase 3 — 일괄 Import

**대상**: 나머지 ~51 leaves

**자동화 스크립트** (`scripts/import/generate-imports.sh`)
1. 입력: `leaf-to-resource-map.csv`, `address-catalog.md`
2. leaf 경로별로 카탈로그 패턴을 매칭하여 `imports.tf` 생성
3. leaf별 init/plan/apply 호출 (의존 순서 준수)
4. 결과를 `docs/import/run-log.csv`에 누적: `leaf, started_at, plan_summary, applied_at, status`

**실행 순서**
DEPLOY-GUIDE의 의존 순서를 그대로 따른다.

```
01.network → 02.storage → 03.shared-services
→ 04.apim → 05.ai-services → 06.compute
→ 07.identity → 08.rbac → 09.connectivity
```

각 스택 내부도 RG → VNet → Subnet → NSG → Route → DNS → … 순.

**검증 게이트**
- 모든 leaf에서 plan no-diff
- `run-log.csv`에 실패 leaf 없음
- 마지막에 전 leaf `terraform plan`을 한 번 더 돌려 일관성 확인 (drift 없음)

### 4.5 Phase 4 — Variable 변경 검증

운영 영향이 적은 시나리오부터 실행하여, 의도된 변경이 의도된 방식(in-place vs replace)으로 plan에 나타나는지 확인한다.

| # | 시나리오 | 변경 위치 | 기대 plan | 위험도 |
|---|---|---|---|---|
| 1 | tag 추가 | 모든 leaf `tags` | `~ update in-place` | 낮음 |
| 2 | 단일 leaf SKU 변경 | `06.compute/linux-monitoring-vm` `vm_size` | `~ update in-place` (가능한 SKU만) | 중간 |
| 3 | NSG 규칙 추가 | `01.network/security-group/network-security-rule/...` | `+ create` (신규 rule), 기존 무변경 | 중간 |
| 4 | CIDR 변경 | 빈 subnet 1개 | `~ update in-place` | 높음 |
| 5 | `project_name` 변경 (= `local.name_prefix` 변경) | tfvars (전체 영향) | **replace 다수** → spec 범위 외, 별도 PR | 매우 높음 |

각 시나리오는 다음 순서로 진행:

1. `terraform plan -out=plan.out` → 출력을 PR/spec 부록에 기록
2. 의도와 일치 여부 검토 (replace가 아니어야 함)
3. `terraform apply plan.out`
4. Azure 포털/CLI로 실제 반영 확인
5. 변경 사항을 원복(롤백)하거나 유지 결정

**검증 게이트**
- 시나리오 1~4 모두 의도된 plan 출력 → apply → Azure 반영 확인
- 시나리오 5는 별도 PR로 분리 (이번 spec에서는 plan 검증만)

## 5. Backend 설정 처리

`azure/` 폴더의 모든 leaf는 `backend.tf`에 `key` 라인이 주석 처리되어 있다. Import 작업 동안은 다음 방식 중 하나로 통일한다.

**방식 선택**: `-backend-config="key=..."` 동적 주입

이유:
- `azure/` 폴더에 commit하지 않고 import 작업이 종료되면 깔끔히 끝낼 수 있음
- 향후 `azure-1/2/3` 배포 방식 선택과 무관하게 동작
- 스크립트로 leaf별 key를 일관되게 생성 가능

```bash
terraform init \
  -backend-config="storage_account_name=tfstatea9911" \
  -backend-config="container_name=tfstate" \
  -backend-config="resource_group_name=terraform-state-rg" \
  -backend-config="key=azure/dev/01.network/resource-group/hub-rg/terraform.tfstate"
```

## 6. Plan diff 발생 시 조정 절차

import 후 `plan`에 변화가 보이면 다음 순서로 원인 파악:

1. **이름/태그 차이**
   - `local.name_prefix`, `var.tags` 가 실제 리소스와 일치하는지 확인
   - tfvars 수정으로 해결 가능한지 우선 검토
2. **모듈 기본값 차이**
   - AVM 모듈이 default로 켜는 옵션(예: `enable_telemetry=true`)을 실제 리소스가 끄고 있는 경우
   - leaf의 `main.tf`에 명시적으로 인자 추가
3. **하위 리소스 누락**
   - VM의 disk, NIC의 IP config 같은 복합 리소스가 별도 import 필요
   - imports.tf에 항목 추가
4. **속성 형식 차이**
   - 대소문자, location 표기(`Korea Central` vs `koreacentral`) 등
5. **destroy/recreate가 나오는 경우**
   - import 주소가 잘못된 것. `terraform state rm` 후 imports.tf 수정 재시도

조정으로 해결할 수 없는 본질적 차이(예: 모듈이 강제로 만드는 리소스가 실 환경엔 없음)는 별도 이슈로 기록하고 해당 leaf는 후속 작업으로 미룬다.

## 7. 롤백 / 에러 처리

| 상황 | 대응 |
|---|---|
| imports.tf 작성 직후, init만 한 상태 | imports.tf 삭제로 종료 |
| `plan`까지 한 상태 | imports.tf 삭제로 종료 (plan은 state 무변경) |
| `apply`로 state에 들어간 후 잘못 발견 | `terraform state rm <addr>` 로 state에서만 제거. 실제 리소스 무영향 |
| backend init 실패 (state 충돌) | leaf 경로의 key가 unique한지 확인. SA 권한 확인 |
| 의존 leaf state 미존재 (`terraform_remote_state` 실패) | 의존 leaf부터 먼저 import. §4.4 의존 순서 준수 |
| Azure resource_id 오타로 import | apply 전이면 imports.tf 수정. apply 후면 state rm 후 재시도 |

## 8. 산출물

| 경로 | 내용 |
|---|---|
| `docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md` | 본 spec |
| `docs/superpowers/plans/2026-05-12-azure-import-and-verify-plan.md` | 실행 계획 (writing-plans 단계) |
| `docs/import/inventory.csv` | Azure 리소스 인벤토리 (Phase 0) |
| `docs/import/leaf-to-resource-map.csv` | leaf ↔ resource_id 매핑 (Phase 0) |
| `docs/import/address-catalog.md` | Import 주소 패턴 카탈로그 (Phase 2) |
| `docs/import/run-log.csv` | leaf별 import 실행 로그 (Phase 3) |
| `scripts/import/generate-imports.sh` | imports.tf 자동 생성기 (Phase 3) |
| `scripts/import/run-import.sh` | leaf별 init/plan/apply 래퍼 (Phase 3) |

## 9. 검증 게이트 요약

| Phase | 게이트 |
|---|---|
| 0 | `az login` OK, state SA 접근 OK, 인벤토리/매핑 CSV 작성 완료 |
| 1 | Pilot leaf plan no-diff, state에 import됨, 절차 문서화 |
| 2 | 9개 대표 leaf plan no-diff, 카탈로그가 모든 모듈 패턴 커버 |
| 3 | 모든 leaf plan no-diff, run-log 실패 없음, 최종 sanity plan 통과 |
| 4 | 시나리오 1~4 의도된 plan/apply, Azure 반영 확인 |

## 10. 가정과 위험

**가정**
- 운영 중 Azure 리소스 이름이 `local.name_prefix` 기반 규칙과 충돌하지 않는다 (`test-x-x-...`)
- state SA `tfstatea9911`은 leaf별 key 충돌 없이 사용 가능하다
- `terraform_remote_state` 의존 그래프는 DEPLOY-GUIDE의 의존 순서와 동일하다
- import 작업 동안 Azure 측에서 동시 수동 변경이 발생하지 않는다

**위험**
- AVM 모듈 버전이 운영 리소스 생성 시점과 다르면 default 속성 차이로 광범위한 diff 발생 가능 → §6.2로 흡수하되 시간 소모 가능성 있음
- `07.identity`/`08.rbac`은 Azure AD provider 권한 별도 필요 → Phase 2 단계에서 인증 점검
- `09.connectivity/peering`은 양쪽 vnet state가 존재해야 함 → 마지막 순서 엄수
- 단일 구독 가정이 깨지면 (실 환경이 이미 분리되었으면) `hub_subscription_id`/`spoke_subscription_id` 별도 주입 필요 → [[hub-spoke-subscription-split-design]] 와 통합 검토
