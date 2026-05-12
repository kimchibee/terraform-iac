# Azure 환경 Import & Variable 검증 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 운영 중인 Azure 리소스를 `azure/` Terraform 트리의 state로 import한 뒤, variable 변경이 의도대로 동작하는지 plan/apply로 검증한다.

**Architecture:** Terraform 1.5+ `import { ... }` 블록을 leaf별 `imports.tf`로 선언 → `init` → `plan` no-diff → `apply` → `imports.tf` 제거. Phase 1 pilot으로 절차를 확정, Phase 2에서 9개 스택 대표 leaf로 모듈 깊이별 import 주소 카탈로그 확정, Phase 3에서 자동화 스크립트로 나머지 leaf 일괄 처리, Phase 4에서 tag/SKU/NSG/CIDR 시나리오로 variable 변경 검증.

**Tech Stack:** Terraform v1.14.6, Azure CLI (`az`), `jq`, `awk`, Bash. Backend: Azure Storage Account `tfstatea9911`.

**참조 Spec:** `docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md`

---

## File Structure

신규/수정 파일:

```
docs/import/
  inventory.json                # az resource list 원본 (Phase 0)
  inventory.csv                 # 필터링된 인벤토리 (Phase 0)
  leaf-to-resource-map.csv      # leaf ↔ terraform addr ↔ resource_id (Phase 0~2 누적)
  address-catalog.md            # 모듈 패턴별 import 주소 카탈로그 (Phase 2)
  run-log.csv                   # leaf별 import 실행 결과 (Phase 3)

scripts/import/
  env.sh                        # 공통 환경변수 (구독, backend SA)
  az-inventory.sh               # Azure 리소스 인벤토리 추출
  leaf-list.sh                  # leaf 경로 나열
  tf-backend-key.sh             # leaf 경로 → backend key 변환
  tf-init-leaf.sh               # 단일 leaf init 래퍼
  tf-plan-leaf.sh               # 단일 leaf plan 래퍼 (no-diff 검증)
  generate-imports.sh           # leaf별 imports.tf 자동 생성 (Phase 3)
  run-import.sh                 # leaf별 init/plan/apply 일괄 (Phase 3)
  run-all-stacks.sh             # 의존 순서대로 전체 실행 (Phase 3)

azure/hub/01.network/resource-group/hub-rg/imports.tf   # Phase 1, 작업 후 제거
azure/<...각 leaf...>/imports.tf                         # Phase 2~3, 각 작업 후 제거
```

---

## Phase 0 — 사전 준비

### Task 0.1: 인증 및 도구 확인

**Files:**
- Create: `scripts/import/env.sh`

- [ ] **Step 1: scripts/import 디렉토리 생성**

```bash
mkdir -p /Users/mzs02-andy/Projects/mz_external/terraform-iac/scripts/import
mkdir -p /Users/mzs02-andy/Projects/mz_external/terraform-iac/docs/import
```

- [ ] **Step 2: 공통 환경 파일 작성**

`scripts/import/env.sh`:

```bash
#!/usr/bin/env bash
# 공통 환경변수 — 작업 시작 시 `source scripts/import/env.sh` 로 로드

# 대상 구독
export AZ_SUB="20e3a0f3-f1af-4cc5-8092-dc9b276a9911"

# Terraform backend (state SA)
export TF_BACKEND_RG="terraform-state-rg"
export TF_BACKEND_SA="tfstatea9911"
export TF_BACKEND_CONTAINER="tfstate"

# Terraform 변수: subscription_id는 spec §5.1에 따라 환경변수로만 주입
export TF_VAR_hub_subscription_id="$AZ_SUB"
export TF_VAR_spoke_subscription_id="$AZ_SUB"

# 리포 루트 (스크립트에서 사용)
export REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export AZURE_ROOT="$REPO_ROOT/azure"
export IMPORT_DOC_DIR="$REPO_ROOT/docs/import"
```

- [ ] **Step 3: 도구 버전 확인**

```bash
terraform -version | head -1
az version --output table | head -3
jq --version
```

Expected:
- terraform: `Terraform v1.14.6` (또는 v1.5 이상)
- az: 임의 버전
- jq: 임의 버전 (없으면 `brew install jq`)

- [ ] **Step 4: Azure 인증 및 구독 설정**

```bash
source scripts/import/env.sh
az login
az account set --subscription "$AZ_SUB"
az account show --query '{name:name, id:id}' -o table
```

Expected: 구독 ID가 `20e3a0f3-...a9911` 와 일치

- [ ] **Step 5: State SA 접근 확인**

```bash
az storage container show \
  --name "$TF_BACKEND_CONTAINER" \
  --account-name "$TF_BACKEND_SA" \
  --auth-mode login \
  --query '{name:name}' -o table
```

Expected: `tfstate` 컨테이너 정보 출력. 권한 오류 시 Storage Blob Data Contributor 부여 필요.

- [ ] **Step 6: 커밋**

```bash
cd /Users/mzs02-andy/Projects/mz_external/terraform-iac
git add scripts/import/env.sh
git commit -m "chore(import): add env.sh for azure import workflow"
```

---

### Task 0.2: Azure 리소스 인벤토리 추출

**Files:**
- Create: `scripts/import/az-inventory.sh`
- Create (generated): `docs/import/inventory.json`, `docs/import/inventory.csv`

- [ ] **Step 1: 인벤토리 스크립트 작성**

`scripts/import/az-inventory.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# 전제: scripts/import/env.sh 가 source 되어 있음

OUT_JSON="$IMPORT_DOC_DIR/inventory.json"
OUT_CSV="$IMPORT_DOC_DIR/inventory.csv"

echo "[1/3] az resource list 실행..."
az resource list --subscription "$AZ_SUB" -o json > "$OUT_JSON"

echo "[2/3] CSV 변환..."
jq -r '
  ["id","type","resourceGroup","name","location"],
  (.[] | [.id, .type, .resourceGroup, .name, .location])
  | @csv
' "$OUT_JSON" > "$OUT_CSV"

echo "[3/3] 요약"
echo "총 리소스: $(jq 'length' "$OUT_JSON")"
echo "RG별:"
jq -r 'group_by(.resourceGroup) | .[] | "\(.[0].resourceGroup): \(length)"' "$OUT_JSON" | sort

echo "산출: $OUT_JSON, $OUT_CSV"
```

- [ ] **Step 2: 실행 권한 부여 후 실행**

```bash
chmod +x scripts/import/az-inventory.sh
source scripts/import/env.sh
./scripts/import/az-inventory.sh
```

Expected: `docs/import/inventory.json`, `inventory.csv` 생성. RG별 리소스 수 출력.

- [ ] **Step 3: 인벤토리 sanity check**

```bash
head -5 docs/import/inventory.csv
wc -l docs/import/inventory.csv
```

Expected: 첫 줄이 헤더, 그 다음부터 리소스 행. 9개 스택 전체 배포라면 최소 수십 개 이상.

- [ ] **Step 4: gitignore 확인 후 커밋**

`docs/import/inventory.json` 은 민감하지 않지만 크기가 크고 자주 재생성되므로 gitignore에 추가.

```bash
echo "docs/import/inventory.json" >> .gitignore
git add .gitignore scripts/import/az-inventory.sh
git commit -m "chore(import): add az inventory extraction script"
```

---

### Task 0.3: leaf → resource_id 매핑 초안

**Files:**
- Create: `scripts/import/leaf-list.sh`
- Create (manual edit 필요): `docs/import/leaf-to-resource-map.csv`

- [ ] **Step 1: leaf 나열 스크립트 작성**

`scripts/import/leaf-list.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
# 모든 leaf (main.tf가 있는 디렉토리) 의 상대 경로 출력
cd "$REPO_ROOT"
find azure -name main.tf -type f \
  -not -path 'azure/ci/*' -not -path 'azure/script/*' \
  | xargs -n1 dirname | sort
```

- [ ] **Step 2: 실행 및 결과 확인**

```bash
chmod +x scripts/import/leaf-list.sh
source scripts/import/env.sh
./scripts/import/leaf-list.sh | tee /tmp/leaf-list.txt
wc -l /tmp/leaf-list.txt
```

Expected: ~61개 leaf 경로 출력 (hub 37 + spoke 24).

- [ ] **Step 3: 매핑 CSV 초안 생성**

`docs/import/leaf-to-resource-map.csv` 헤더와 행 형식:

```
leaf_path,tf_address,az_resource_id,notes
azure/hub/01.network/resource-group/hub-rg,module.resource_group.azurerm_resource_group.this,/subscriptions/20e3a0f3-.../resourceGroups/test-x-x-rg,
```

작성 절차:
1. `/tmp/leaf-list.txt` 의 각 leaf 경로를 `leaf_path` 컬럼에 채움 (스크립트로 생성)
2. 각 leaf의 `main.tf` 를 읽고 모듈 호출/리소스 정의를 기반으로 `tf_address` 컬럼 채움 (Phase 2까지 미확정인 leaf는 빈칸)
3. `inventory.csv` 와 대조하여 `az_resource_id` 채움

초안 자동 생성용 보조 명령:

```bash
{
  echo "leaf_path,tf_address,az_resource_id,notes"
  while IFS= read -r leaf; do
    echo "$leaf,,,"
  done < /tmp/leaf-list.txt
} > docs/import/leaf-to-resource-map.csv

wc -l docs/import/leaf-to-resource-map.csv
```

Expected: 헤더 + ~61줄.

- [ ] **Step 4: pilot leaf (hub-rg) 1줄만 수동으로 채우기**

`docs/import/leaf-to-resource-map.csv` 에서 hub-rg 행을 직접 편집:

```
azure/hub/01.network/resource-group/hub-rg,module.resource_group.azurerm_resource_group.this,/subscriptions/20e3a0f3-f1af-4cc5-8092-dc9b276a9911/resourceGroups/test-x-x-rg,pilot
```

resource_id는 `az group show --name test-x-x-rg --query id -o tsv` 출력값으로 확인.

- [ ] **Step 5: 검증 — pilot row의 az_resource_id 가 실제 존재**

```bash
TARGET=$(awk -F, '$4=="pilot" {print $3}' docs/import/leaf-to-resource-map.csv)
echo "TARGET=$TARGET"
az resource show --ids "$TARGET" --query '{id:id, type:type}' -o table
```

Expected: hub-rg 정보 출력. 출력 없으면 RG 이름이 `local.name_prefix` 와 다른 것 — locals 또는 tfvars 조정 후속 작업 필요.

- [ ] **Step 6: 커밋**

```bash
git add scripts/import/leaf-list.sh docs/import/leaf-to-resource-map.csv
git commit -m "chore(import): seed leaf-to-resource map with pilot row"
```

---

## Phase 1 — Pilot (hub-rg)

### Task 1.1: hub-rg backend init

**Files:**
- Create: `scripts/import/tf-init-leaf.sh`
- Modify (작업 후 원복): `azure/hub/01.network/resource-group/hub-rg/backend.tf` (변경 없이 init에 -backend-config만 사용)

- [ ] **Step 1: backend key 변환 헬퍼 작성**

`scripts/import/tf-backend-key.sh`:

```bash
#!/usr/bin/env bash
# leaf 경로 → backend state key 변환
# 예: azure/hub/01.network/resource-group/hub-rg
#  → azure/dev/hub/01.network/resource-group/hub-rg/terraform.tfstate
set -euo pipefail

LEAF="${1:?leaf path required (e.g. azure/hub/01.network/.../hub-rg)}"
# azure/ 제거 후 dev/ 삽입
SUFFIX="${LEAF#azure/}"
echo "azure/dev/${SUFFIX}/terraform.tfstate"
```

- [ ] **Step 2: init 래퍼 작성**

`scripts/import/tf-init-leaf.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

LEAF="${1:?leaf path required}"
KEY=$("$(dirname "$0")/tf-backend-key.sh" "$LEAF")

cd "$REPO_ROOT/$LEAF"
terraform init \
  -reconfigure \
  -backend-config="resource_group_name=$TF_BACKEND_RG" \
  -backend-config="storage_account_name=$TF_BACKEND_SA" \
  -backend-config="container_name=$TF_BACKEND_CONTAINER" \
  -backend-config="key=$KEY"
```

- [ ] **Step 3: 권한 부여 및 hub-rg에 init 실행**

```bash
chmod +x scripts/import/tf-backend-key.sh scripts/import/tf-init-leaf.sh
source scripts/import/env.sh
./scripts/import/tf-init-leaf.sh azure/hub/01.network/resource-group/hub-rg
```

Expected: `Terraform has been successfully initialized!` 메시지. `.terraform/` 디렉토리 생성됨.

- [ ] **Step 4: 커밋**

```bash
git add scripts/import/tf-backend-key.sh scripts/import/tf-init-leaf.sh
git commit -m "chore(import): add terraform init wrapper for per-leaf backend"
```

---

### Task 1.2: hub-rg imports.tf 작성 및 첫 plan

**Files:**
- Create (temp): `azure/hub/01.network/resource-group/hub-rg/imports.tf`

- [ ] **Step 1: imports.tf 작성**

`azure/hub/01.network/resource-group/hub-rg/imports.tf`:

```hcl
# 임시 import 블록 — apply 후 제거할 것
import {
  id = "/subscriptions/20e3a0f3-f1af-4cc5-8092-dc9b276a9911/resourceGroups/test-x-x-rg"
  to = module.resource_group.azurerm_resource_group.this
}
```

- [ ] **Step 2: terraform.tfvars 작성 (subscription 라인 제거된 형태)**

해당 leaf의 `terraform.tfvars` 는 이미 존재하지만, spec §5.1에 따라 `hub_subscription_id` 라인이 제거되어야 한다. 현재 상태 확인:

```bash
grep -E 'subscription_id' azure/hub/01.network/resource-group/hub-rg/terraform.tfvars || echo "OK: no subscription_id in tfvars"
```

`subscription_id` 라인이 있다면 제거:

```bash
sed -i.bak '/subscription_id/d' azure/hub/01.network/resource-group/hub-rg/terraform.tfvars
rm azure/hub/01.network/resource-group/hub-rg/terraform.tfvars.bak
```

(이미 hub-spoke-subscription-split 작업으로 제거되어 있을 수 있음.)

- [ ] **Step 3: plan 실행**

```bash
cd azure/hub/01.network/resource-group/hub-rg
terraform plan -out=plan.out 2>&1 | tee /tmp/plan-hub-rg.log
```

Expected (성공 시): 마지막 줄에 `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.`

기록: `/tmp/plan-hub-rg.log` 의 핵심 부분을 후속 commit 메시지/로그에 인용.

- [ ] **Step 4: plan 출력에 따른 분기**

플랜 결과가 다음 중 어느 경우인지 확인:

- (A) `1 to import, 0 to add, 0 to change, 0 to destroy` → 다음 Task로 이동
- (B) `1 to import, 0 to add, N to change, 0 to destroy` → Task 1.3 (diff 조정) 으로 이동
- (C) `to destroy` 가 보임 → import 주소가 잘못됨. `imports.tf` 의 `to` 또는 `id` 재확인
- (D) `Error: ...` → 메시지에 따라 backend init, provider auth, 모듈 다운로드 등 점검

이 시점에 `cd $REPO_ROOT` 로 돌아온다.

```bash
cd "$REPO_ROOT"
```

---

### Task 1.3: hub-rg plan diff 조정

(Task 1.2에서 (B) 또는 (C) 분기 시 수행. (A) 인 경우 이 Task 건너뛰고 1.4로.)

**Files:**
- Modify: leaf의 `locals.tf` 또는 `terraform.tfvars` 또는 `main.tf` (실제 차이에 따라)

- [ ] **Step 1: plan 출력에서 diff 항목 식별**

```bash
cd azure/hub/01.network/resource-group/hub-rg
terraform show plan.out | less
```

각 `~` 또는 `+` 라인을 확인하고 다음 카테고리로 분류:

- 이름/태그/location 등 단순 값 차이 → tfvars/locals 조정
- 모듈 기본값과 실 리소스 옵션 차이 → main.tf 모듈 호출에 인자 추가
- 본질적 차이 (예: 운영 환경에 추가 sub-resource 존재) → 별도 import 추가 또는 후속 이슈

- [ ] **Step 2: 가장 흔한 차이 — tags 조정**

운영 리소스의 실제 태그 조회:

```bash
az group show --name test-x-x-rg --query tags -o json
```

출력값을 `terraform.tfvars` 의 `tags` 와 일치시킴. (예: 운영 리소스에 `CostCenter` 가 있으면 tfvars에도 추가)

- [ ] **Step 3: 변경 후 plan 재실행**

```bash
cd azure/hub/01.network/resource-group/hub-rg
terraform plan -out=plan.out
```

Expected: `Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.`

`0 to change` 가 될 때까지 Step 1~3 반복. 본질적 차이가 남아 코드 조정으로 해결 불가하면 leaf를 보류 상태로 분류하고 spec §10 위험 섹션에 기록.

- [ ] **Step 4: 조정한 파일 commit (apply 전, imports.tf 는 제외)**

```bash
cd "$REPO_ROOT"
# imports.tf 는 작업 종료 후 삭제될 임시 파일이므로 staging 에서 명시 제외
git add azure/hub/01.network/resource-group/hub-rg/terraform.tfvars \
        azure/hub/01.network/resource-group/hub-rg/locals.tf \
        azure/hub/01.network/resource-group/hub-rg/main.tf 2>/dev/null || true
# 위 명령에서 실제 변경된 파일만 staging됨
git status azure/hub/01.network/resource-group/hub-rg/
git commit -m "chore(hub-rg): align variables with existing Azure resource for import"
```

---

### Task 1.4: hub-rg apply, sanity, 마무리

- [ ] **Step 1: apply 실행**

```bash
cd azure/hub/01.network/resource-group/hub-rg
terraform apply plan.out
```

Expected: `Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.`

- [ ] **Step 2: state 확인**

```bash
terraform state list
```

Expected: `module.resource_group.azurerm_resource_group.this` 가 목록에 보임.

- [ ] **Step 3: imports.tf 제거 및 sanity plan**

```bash
rm imports.tf plan.out
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

- [ ] **Step 4: Azure 측 변경 없음 재확인**

```bash
az group show --name test-x-x-rg --query '{id:id, name:name, location:location, tags:tags}' -o json
```

운영 리소스의 ID/이름/태그가 import 전과 동일한지 육안 확인.

- [ ] **Step 5: run-log.csv 초기화 및 hub-rg 행 추가**

```bash
cd "$REPO_ROOT"
mkdir -p docs/import
{
  echo "leaf_path,started_at,plan_summary,applied_at,status"
  echo "azure/hub/01.network/resource-group/hub-rg,$(date -u +%FT%TZ),1 imported 0 changed,$(date -u +%FT%TZ),success"
} > docs/import/run-log.csv
```

- [ ] **Step 6: 커밋**

이 시점에 leaf 디렉토리는 import 시작 전 상태와 동일 (imports.tf 는 Step 3에서 제거됨). state 변화만 외부 backend 에 기록.

```bash
git add docs/import/run-log.csv
git commit -m "feat(import): pilot - import hub resource-group into terraform state"
```

- [ ] **Step 7: Phase 1 절차 회고를 spec에 반영**

만약 Pilot 중 spec §6 조정 절차에 빠진 함정이 있었다면 spec을 업데이트:

```bash
$EDITOR docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md
# 발견된 함정/예외를 §6 또는 §10 에 추가
git add docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md
git commit -m "docs(superpowers): spec update from Phase 1 pilot findings"
```

(변경 없으면 이 Step 건너뜀.)

---

## Phase 2 — 스택별 대표 leaf (Address Catalog)

각 Task는 Phase 1과 동일한 작업 단위(init → imports.tf → plan → adjust → apply → sanity → log → commit)를 다른 leaf에 적용한다. 본 plan에서는 **leaf별 핵심 파라미터만 명시**하고 절차는 Phase 1 Task 1.1~1.4를 인용한다. 단, AVM 모듈 내부 리소스 주소 확인 절차는 첫 leaf(hub-vnet)에서 한 번 상세히 보여준다.

### Task 2.1: 01.network — hub-vnet

**대상 leaf**: `azure/hub/01.network/vnet/hub-vnet`
**예상 패턴**: AVM 중첩 (`module.X.azurerm_virtual_network.vnet[0]`)

- [ ] **Step 1: leaf init (Task 1.1 절차 재사용)**

```bash
source scripts/import/env.sh
./scripts/import/tf-init-leaf.sh azure/hub/01.network/vnet/hub-vnet
```

- [ ] **Step 2: 모듈 내부 리소스 주소 식별**

AVM 모듈은 init 후 `.terraform/modules/<key>/main.tf` 에 실제 리소스를 정의한다. hub-vnet 모듈의 리소스 목록 확인:

```bash
cd azure/hub/01.network/vnet/hub-vnet
grep -RhE '^resource "azurerm_' .terraform/modules/hub_vnet/ | sort -u
```

Expected: `resource "azurerm_virtual_network" "vnet" { ... }` 등의 라인 — `module.hub_vnet.azurerm_virtual_network.vnet[0]` 가 import 주소.

`[0]` 첨자는 모듈 내부에서 `count`/`for_each` 를 쓸 때 필요. 모듈이 `count = var.create_vnet ? 1 : 0` 식으로 작성되어 있으면 `[0]` 필요. `for_each` 면 키. 단일 리소스면 첨자 없음. 모듈 코드 확인 후 결정.

- [ ] **Step 3: Azure 측 리소스 ID 확보**

```bash
az network vnet show \
  --name test-x-x-vnet \
  --resource-group test-x-x-rg \
  --query id -o tsv
```

(VNet 이름은 leaf의 `locals.tf` 에서 `local.hub_vnet_name = "${local.name_prefix}-vnet"` 으로 계산 — 결과는 `test-x-x-vnet`)

- [ ] **Step 4: imports.tf 작성**

`azure/hub/01.network/vnet/hub-vnet/imports.tf`:

```hcl
import {
  id = "/subscriptions/20e3a0f3-f1af-4cc5-8092-dc9b276a9911/resourceGroups/test-x-x-rg/providers/Microsoft.Network/virtualNetworks/test-x-x-vnet"
  to = module.hub_vnet.azurerm_virtual_network.vnet[0]
}
```

(첨자 형태는 Step 2 결과에 따라 조정.)

- [ ] **Step 5: plan, 조정, apply (Task 1.2~1.4 절차 재사용)**

Phase 1과 동일 절차 반복. plan no-diff 확인 → apply → imports.tf 제거 → sanity plan → run-log.csv 행 추가 → commit.

- [ ] **Step 6: leaf-to-resource-map.csv 업데이트**

```
azure/hub/01.network/vnet/hub-vnet,module.hub_vnet.azurerm_virtual_network.vnet[0],/subscriptions/.../virtualNetworks/test-x-x-vnet,rep-01.network
```

```bash
git add docs/import/leaf-to-resource-map.csv azure/hub/01.network/vnet/hub-vnet/imports.tf 2>/dev/null || true
git rm --cached azure/hub/01.network/vnet/hub-vnet/imports.tf 2>/dev/null || true
git add docs/import/run-log.csv
git commit -m "feat(import): rep leaf - 01.network/vnet/hub-vnet"
```

---

### Task 2.2: 02.storage — monitoring

**대상 leaf**: `azure/hub/02.storage/monitoring`
**예상 패턴**: Storage Account (단일 리소스 또는 sub-resource 다수)

- [ ] **Step 1: leaf 디렉토리 구성 확인**

```bash
ls azure/hub/02.storage/monitoring
cat azure/hub/02.storage/monitoring/main.tf
```

- [ ] **Step 2: 모듈 내부 리소스 목록 식별 (Task 2.1 Step 2 방법 재사용)**

```bash
./scripts/import/tf-init-leaf.sh azure/hub/02.storage/monitoring
cd azure/hub/02.storage/monitoring
grep -RhE '^resource "azurerm_' .terraform/modules/ | sort -u
```

Storage Account 모듈은 다음 sub-resource를 동반할 수 있음 — 모두 import 필요할 수 있음:
- `azurerm_storage_account`
- `azurerm_storage_container` (선택)
- `azurerm_management_lock` (선택)
- `azurerm_role_assignment` (선택)
- `azurerm_private_endpoint` (선택)

- [ ] **Step 3: Azure 측 인벤토리 확인**

```bash
cd "$REPO_ROOT"
grep -i 'storage\|Microsoft.Storage' docs/import/inventory.csv | head -10
```

운영 SA의 정확한 이름을 확인 (예: `testxxmonsa` 등 truncated 이름일 수 있음).

- [ ] **Step 4: imports.tf 작성 (sub-resource 별로 import 블록)**

```hcl
import {
  id = "/subscriptions/.../Microsoft.Storage/storageAccounts/<sa-name>"
  to = module.monitoring_sa.azurerm_storage_account.this
}

# 운영 환경에 존재하는 컨테이너/blob/lock 각각 추가
import {
  id = "/subscriptions/.../storageAccounts/<sa-name>/blobServices/default/containers/<ct-name>"
  to = module.monitoring_sa.azurerm_storage_container.this["<ct-key>"]
}
```

- [ ] **Step 5: plan/adjust/apply (Task 1.2~1.4 절차)**

특히 `network_rules`, `blob_properties` 등이 default 값과 차이 나면 diff가 광범위 — main.tf 또는 tfvars에 명시 인자 추가.

- [ ] **Step 6: leaf-to-resource-map.csv, run-log.csv 업데이트 후 commit**

```bash
git commit -m "feat(import): rep leaf - 02.storage/monitoring"
```

---

### Task 2.3: 03.shared-services — log-analytics-workspace

**대상 leaf**: `azure/hub/03.shared-services/log-analytics-workspace` (정확한 sub-leaf 1개 선정 후 진행)

- [ ] **Step 1: 하위 leaf 1개 선정**

```bash
ls azure/hub/03.shared-services/log-analytics-workspace
```

가장 단순한 1개를 선택 (예: 첫 번째).

- [ ] **Step 2~6: Task 2.1 절차 동일 적용**

LA Workspace 모듈은 일반적으로:
- `azurerm_log_analytics_workspace`
- `azurerm_log_analytics_solution` (선택, 다중 가능)

```hcl
import {
  id = "/subscriptions/.../Microsoft.OperationalInsights/workspaces/<name>"
  to = module.la_workspace.azurerm_log_analytics_workspace.this
}
```

leaf-to-resource-map.csv 업데이트, run-log 기록, commit:

```bash
git commit -m "feat(import): rep leaf - 03.shared-services/log-analytics-workspace"
```

---

### Task 2.4: 04.apim — spoke/04.apim/workload

**대상 leaf**: `azure/spoke/04.apim/workload`
**예상 패턴**: 복합 (APIM service + named values + APIs + diagnostics)

- [ ] **Step 1~6: Task 2.1 절차 적용**

핵심 sub-resource:
- `azurerm_api_management`
- `azurerm_api_management_named_value` (다중)
- `azurerm_api_management_api` (다중)
- `azurerm_api_management_diagnostic` (선택)
- `azurerm_private_endpoint` (선택)

```hcl
import {
  id = "/subscriptions/.../Microsoft.ApiManagement/service/<apim-name>"
  to = module.apim_workload.azurerm_api_management.this
}
# 각 named_value, api 별 import 블록 추가
```

```bash
git commit -m "feat(import): rep leaf - 04.apim/workload"
```

---

### Task 2.5: 05.ai-services — spoke/05.ai-services/workload

**대상 leaf**: `azure/spoke/05.ai-services/workload`
**예상 패턴**: Cognitive Services account + private endpoint

- [ ] **Step 1~6: Task 2.1 절차 적용**

```hcl
import {
  id = "/subscriptions/.../Microsoft.CognitiveServices/accounts/<aoai-name>"
  to = module.ai_workload.azurerm_cognitive_account.this
}
# Deployment, private endpoint 별 import 블록 추가
```

```bash
git commit -m "feat(import): rep leaf - 05.ai-services/workload"
```

---

### Task 2.6: 06.compute — linux-monitoring-vm

**대상 leaf**: `azure/hub/06.compute/linux-monitoring-vm`
**예상 패턴**: VM 복합 (vm + nic + os_disk + data_disk + extension)

- [ ] **Step 1~6: Task 2.1 절차 적용**

핵심 sub-resource (각각 별도 import 필요):
- `azurerm_linux_virtual_machine`
- `azurerm_network_interface` (1개 이상)
- `azurerm_managed_disk` (OS Disk는 VM에 흡수되지만 추가 데이터 디스크는 별도)
- `azurerm_virtual_machine_extension` (Azure Monitor Agent 등)

```hcl
import {
  id = "/subscriptions/.../Microsoft.Compute/virtualMachines/<vm-name>"
  to = module.linux_vm.azurerm_linux_virtual_machine.this[0]
}

import {
  id = "/subscriptions/.../Microsoft.Network/networkInterfaces/<nic-name>"
  to = module.linux_vm.azurerm_network_interface.this[0]
}

# 데이터 디스크가 있으면 추가
import {
  id = "/subscriptions/.../Microsoft.Compute/disks/<disk-name>"
  to = module.linux_vm.azurerm_managed_disk.this["data0"]
}
```

```bash
git commit -m "feat(import): rep leaf - 06.compute/linux-monitoring-vm"
```

---

### Task 2.7: 07.identity — group-membership

**대상 leaf**: `azure/hub/07.identity/group-membership`
**예상 패턴**: Azure AD provider (azuread)

- [ ] **Step 1: provider 차이 확인**

```bash
cat azure/hub/07.identity/group-membership/provider.tf
```

`azuread` provider가 별도로 선언되어 있는지 확인. 인증은 `az login` 으로 충분하나 권한(Directory Reader 이상)이 필요.

- [ ] **Step 2: 멤버십 ID 형식 확인**

`azuread_group_member` 의 import ID 형식은:
```
<group-object-id>/member/<member-object-id>
```

예:
```bash
az ad group member list --group <group-name> -o table
```

- [ ] **Step 3~7: Task 2.1 절차 적용**

```hcl
import {
  id = "<group-object-id>/member/<member-object-id>"
  to = module.group_membership.azuread_group_member.this["<key>"]
}
```

```bash
git commit -m "feat(import): rep leaf - 07.identity/group-membership"
```

(주의: spec §10 위험에 명시된 placeholder group_object_id 4개 leaf는 import 대상에서 제외 — Azure AD 그룹 생성 선행 필요.)

---

### Task 2.8: 08.rbac — authorization

**대상 leaf**: `azure/hub/08.rbac/authorization`
**예상 패턴**: role assignment 다중

- [ ] **Step 1~6: Task 2.1 절차 적용**

`azurerm_role_assignment` 의 import ID는 GUID 기반:

```bash
az role assignment list --scope <scope-id> --query "[].id" -o tsv
```

```hcl
import {
  id = "/subscriptions/.../providers/Microsoft.Authorization/roleAssignments/<guid>"
  to = module.authorization.azurerm_role_assignment.this["<key>"]
}
```

```bash
git commit -m "feat(import): rep leaf - 08.rbac/authorization"
```

---

### Task 2.9: 09.connectivity — hub/peering

**대상 leaf**: `azure/hub/09.connectivity/peering`
**예상 패턴**: VNet Peering (양방향이면 hub→spoke, spoke→hub 별도 leaf)

- [ ] **Step 1: 선행 state 확인**

Peering 모듈은 `data.terraform_remote_state.<vnet>` 로 vnet output을 참조. hub-vnet, spoke-vnet leaf가 이미 import 완료되어 state가 SA에 존재해야 함.

```bash
az storage blob list \
  --container-name "$TF_BACKEND_CONTAINER" \
  --account-name "$TF_BACKEND_SA" \
  --auth-mode login \
  --query "[?contains(name, 'vnet')].name" -o table
```

Expected: `azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate` 와 `.../spoke-vnet/terraform.tfstate` 가 목록에 보임.

- [ ] **Step 2: Peering ID 확보**

```bash
az network vnet peering list \
  --vnet-name test-x-x-vnet \
  --resource-group test-x-x-rg \
  --query "[].{name:name, id:id}" -o table
```

- [ ] **Step 3~6: Task 2.1 절차 적용**

```hcl
import {
  id = "/subscriptions/.../virtualNetworks/test-x-x-vnet/virtualNetworkPeerings/<peering-name>"
  to = module.hub_to_spoke_peering.azurerm_virtual_network_peering.this[0]
}
```

```bash
git commit -m "feat(import): rep leaf - 09.connectivity/peering"
```

---

### Task 2.10: address-catalog.md 작성

**Files:**
- Create: `docs/import/address-catalog.md`

- [ ] **Step 1: 카탈로그 작성**

Task 2.1~2.9 에서 확인한 leaf별 import 주소 패턴을 분류해 기록.

`docs/import/address-catalog.md`:

```markdown
# Import 주소 패턴 카탈로그

Phase 2에서 9개 스택 대표 leaf로 확정한 모듈 패턴.
Phase 3 자동화 스크립트는 이 카탈로그를 기준으로 leaf별 imports.tf 를 생성한다.

## 패턴 A — 단일 리소스 모듈
**예**: 01.network/resource-group/hub-rg
```hcl
to = module.resource_group.azurerm_resource_group.this
```

## 패턴 B — AVM 중첩 (count 사용)
**예**: 01.network/vnet/hub-vnet
```hcl
to = module.<key>.azurerm_virtual_network.vnet[0]
```

## 패턴 C — for_each 모듈
**예**: 01.network/subnet/* (각 subnet leaf)
```hcl
to = module.<key>.azurerm_subnet.this[0]
```

## 패턴 D — VM 복합
**예**: 06.compute/linux-monitoring-vm
- vm: `module.<key>.azurerm_linux_virtual_machine.this[0]`
- nic: `module.<key>.azurerm_network_interface.this[0]`
- managed_disk: `module.<key>.azurerm_managed_disk.this["<key>"]`

## 패턴 E — Cross-state 의존 (peering)
**예**: 09.connectivity/peering
- 선행 state 필요: hub-vnet, spoke-vnet
```hcl
to = module.<key>.azurerm_virtual_network_peering.this[0]
```

## 패턴 F — Azure AD provider
**예**: 07.identity/group-membership
- import ID 형식: `<group-id>/member/<member-id>`
```hcl
to = module.<key>.azuread_group_member.this["<member-key>"]
```

## 패턴 G — Role Assignment (GUID)
**예**: 08.rbac/authorization
```hcl
to = module.<key>.azurerm_role_assignment.this["<key>"]
```
```

(Task 2.1~2.9 실제 결과로 빈 칸 채울 것.)

- [ ] **Step 2: 커밋**

```bash
git add docs/import/address-catalog.md
git commit -m "docs(import): record address pattern catalog from Phase 2"
```

---

## Phase 3 — 일괄 Import

### Task 3.1: generate-imports.sh 작성

**Files:**
- Create: `scripts/import/generate-imports.sh`

- [ ] **Step 1: 스크립트 작성**

`scripts/import/generate-imports.sh`:

```bash
#!/usr/bin/env bash
# leaf-to-resource-map.csv 의 각 행에 대해 leaf/imports.tf 를 생성
# 카탈로그 패턴 매칭은 단순화: tf_address 컬럼이 채워져 있어야 함
set -euo pipefail

MAP="$IMPORT_DOC_DIR/leaf-to-resource-map.csv"

# CSV 헤더 스킵하고 행 순회 (tf_address, resource_id 채워진 행만)
tail -n +2 "$MAP" | while IFS=',' read -r leaf addr rid notes; do
  if [[ -z "$addr" || -z "$rid" ]]; then
    echo "[skip] $leaf (tf_address or resource_id empty)"
    continue
  fi
  TARGET="$REPO_ROOT/$leaf/imports.tf"
  # 동일 leaf에 여러 import이 있는 경우 같은 파일에 누적 작성
  if [[ ! -f "$TARGET" ]]; then
    echo "# Generated by scripts/import/generate-imports.sh — remove after apply" > "$TARGET"
  fi
  cat >> "$TARGET" <<EOF

import {
  id = "$rid"
  to = $addr
}
EOF
  echo "[gen] $leaf"
done
```

- [ ] **Step 2: dry-run 테스트**

```bash
chmod +x scripts/import/generate-imports.sh
source scripts/import/env.sh
# leaf-to-resource-map.csv 에 1~2행만 채운 상태로 테스트
./scripts/import/generate-imports.sh
ls azure/hub/01.network/resource-group/hub-rg/imports.tf 2>/dev/null && echo "exists"
```

Expected: pilot 행은 이미 apply 후 제거됐으므로 다시 생성됨. 실험 후 삭제.

```bash
rm azure/hub/01.network/resource-group/hub-rg/imports.tf
```

- [ ] **Step 3: 커밋**

```bash
git add scripts/import/generate-imports.sh
git commit -m "chore(import): add imports.tf generator script"
```

---

### Task 3.2: run-import.sh 작성

**Files:**
- Create: `scripts/import/run-import.sh`, `scripts/import/tf-plan-leaf.sh`

- [ ] **Step 1: plan 래퍼 작성**

`scripts/import/tf-plan-leaf.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
LEAF="${1:?leaf path}"
cd "$REPO_ROOT/$LEAF"
terraform plan -out=plan.out -input=false -no-color | tee /tmp/plan-out.log
# 요약 라인 추출
grep -E '^Plan: ' /tmp/plan-out.log | head -1
```

- [ ] **Step 2: leaf별 init/plan/apply 래퍼 작성**

`scripts/import/run-import.sh`:

```bash
#!/usr/bin/env bash
# 단일 leaf에 대해 init → plan → apply 일괄 실행, run-log.csv에 기록
# Pre-condition: imports.tf 가 leaf 디렉토리에 이미 생성되어 있음
set -euo pipefail

LEAF="${1:?leaf path}"
LOG="$IMPORT_DOC_DIR/run-log.csv"
STARTED=$(date -u +%FT%TZ)

cd "$REPO_ROOT"

echo "[run-import] $LEAF — init"
"$REPO_ROOT/scripts/import/tf-init-leaf.sh" "$LEAF" >/dev/null

echo "[run-import] $LEAF — plan"
cd "$REPO_ROOT/$LEAF"
PLAN_OUT=$(terraform plan -out=plan.out -input=false -no-color 2>&1)
SUMMARY=$(echo "$PLAN_OUT" | grep -E '^Plan: ' | head -1)
echo "  $SUMMARY"

# "0 to change, 0 to destroy" 확인
if ! echo "$SUMMARY" | grep -qE '0 to change, 0 to destroy'; then
  echo "[run-import] $LEAF — DIFF DETECTED, NOT APPLYING"
  echo "$LEAF,$STARTED,\"$SUMMARY\",,diff-detected" >> "$LOG"
  exit 2
fi

echo "[run-import] $LEAF — apply"
terraform apply -input=false plan.out >/dev/null
APPLIED=$(date -u +%FT%TZ)

# imports.tf 제거 후 sanity plan
rm -f imports.tf plan.out
terraform plan -no-color > /tmp/sanity.log 2>&1 || true
if grep -q "No changes" /tmp/sanity.log; then
  STATUS="success"
else
  STATUS="sanity-diff"
fi

echo "$LEAF,$STARTED,\"$SUMMARY\",$APPLIED,$STATUS" >> "$LOG"
echo "[run-import] $LEAF — $STATUS"
```

- [ ] **Step 3: 권한 부여 및 단일 leaf로 dry-run**

```bash
chmod +x scripts/import/tf-plan-leaf.sh scripts/import/run-import.sh
source scripts/import/env.sh
```

dry-run은 Phase 3.3 의 첫 leaf에서 실제 실행.

- [ ] **Step 4: 커밋**

```bash
git add scripts/import/tf-plan-leaf.sh scripts/import/run-import.sh
git commit -m "chore(import): add per-leaf run-import wrapper"
```

---

### Task 3.3: 나머지 leaf 매핑 채우기

**Files:**
- Modify: `docs/import/leaf-to-resource-map.csv`

- [ ] **Step 1: 패턴 카탈로그 기반으로 매핑 일괄 입력**

Phase 2 카탈로그를 보고 매핑 CSV의 빈 행을 채운다. 도구로 자동 매칭이 어려운 부분(특히 sub-resource)은 수동 편집.

작업 단위:
1. 같은 패턴의 leaf 그룹별로 처리 (예: 모든 subnet leaf 한 번에)
2. `az resource list` 결과에서 leaf 이름과 매치되는 리소스 ID 입력
3. 행 수 확인: 각 leaf당 최소 1행, sub-resource 있으면 같은 leaf_path로 다중 행

권장 보조 명령:

```bash
# 특정 leaf 그룹의 후보 azure 리소스 출력
grep 'Microsoft.Network/virtualNetworks/subnets' docs/import/inventory.csv
```

- [ ] **Step 2: 입력 후 검증**

```bash
# 빈 tf_address/resource_id 행 카운트
awk -F, 'NR>1 && ($2=="" || $3=="") { c++ } END { print "incomplete rows:", c }' \
  docs/import/leaf-to-resource-map.csv

# 채워진 leaf 수
awk -F, 'NR>1 && $2!="" && $3!="" { print $1 }' docs/import/leaf-to-resource-map.csv | sort -u | wc -l
```

Expected: incomplete 0 (보류 leaf 제외 후), 채워진 leaf 수가 50+ (placeholder 4개 제외).

- [ ] **Step 3: 커밋**

```bash
git add docs/import/leaf-to-resource-map.csv
git commit -m "chore(import): fill leaf-to-resource map for remaining leaves"
```

---

### Task 3.4: 일괄 실행 — 의존 순서대로

**Files:**
- Create: `scripts/import/run-all-stacks.sh`

- [ ] **Step 1: 의존 순서 정의 스크립트 작성**

`scripts/import/run-all-stacks.sh`:

```bash
#!/usr/bin/env bash
# 모든 leaf를 의존 순서대로 import 실행
# Pre-condition:
#  - scripts/import/env.sh source 됨
#  - leaf-to-resource-map.csv 가 채워져 있음
#  - generate-imports.sh 가 한 번 실행되어 leaf별 imports.tf 가 생성됨
set -euo pipefail

# 스택 순서 (DEPLOY-GUIDE 와 동일)
STACK_ORDER=(
  "01.network/resource-group"
  "01.network/vnet"
  "01.network/subnet"
  "01.network/security-group"
  "01.network/route"
  "01.network/dns"
  "01.network/public-ip"
  "01.network/virtual-network-gateway"
  "02.storage"
  "03.shared-services"
  "04.apim"
  "05.ai-services"
  "06.compute"
  "07.identity"
  "08.rbac"
  "09.connectivity"
)

for prefix in "${STACK_ORDER[@]}"; do
  for side in hub spoke; do
    BASE="azure/$side/$prefix"
    [[ -d "$REPO_ROOT/$BASE" ]] || continue
    # main.tf 있는 leaf 디렉토리 나열
    find "$REPO_ROOT/$BASE" -name main.tf -type f | while read mf; do
      leaf_abs=$(dirname "$mf")
      leaf="${leaf_abs#$REPO_ROOT/}"
      # imports.tf 가 있는 경우에만 실행
      if [[ ! -f "$leaf_abs/imports.tf" ]]; then
        echo "[skip] $leaf (no imports.tf)"
        continue
      fi
      echo "==== $leaf ===="
      "$REPO_ROOT/scripts/import/run-import.sh" "$leaf" || {
        echo "[STOP] $leaf 실패 — 중단"
        exit 1
      }
    done
  done
done

echo "[done] 모든 스택 완료"
```

- [ ] **Step 2: imports.tf 일괄 생성**

```bash
source scripts/import/env.sh
chmod +x scripts/import/run-all-stacks.sh
./scripts/import/generate-imports.sh
```

생성된 파일 수 확인:

```bash
find azure -name imports.tf -type f | wc -l
```

Expected: 매핑 CSV에 채워진 leaf 수와 일치.

- [ ] **Step 3: dry-run — 첫 스택만 실행**

먼저 한 스택 (01.network/resource-group) 만 돌려 봄:

```bash
# 임시 단축 실행: 첫 디렉토리만
for mf in $(find azure -path 'azure/*/01.network/resource-group/*/main.tf'); do
  leaf=$(dirname "$mf")
  leaf="${leaf#$REPO_ROOT/}"
  leaf="${leaf#./}"
  [[ -f "$leaf/imports.tf" ]] || continue
  echo "=> $leaf"
  scripts/import/run-import.sh "$leaf"
done
```

Expected: run-log.csv 에 `success` 행이 추가됨. 실패 시 plan 출력 확인 후 매핑/카탈로그 수정.

- [ ] **Step 4: 전체 실행**

```bash
./scripts/import/run-all-stacks.sh 2>&1 | tee /tmp/run-all.log
```

Expected: 모든 leaf 가 `success` 로 끝남. `diff-detected` 가 발생한 leaf는:
1. plan 출력 확인 (`leaf/plan.out` 또는 재실행)
2. spec §6 조정 절차 적용
3. 해당 leaf만 다시 `run-import.sh` 실행

- [ ] **Step 5: 결과 요약**

```bash
awk -F, 'NR>1 { c[$5]++ } END { for (s in c) print s": "c[s] }' docs/import/run-log.csv
```

Expected: `success: N`. 실패가 0 가 될 때까지 반복.

- [ ] **Step 6: 커밋**

```bash
git add scripts/import/run-all-stacks.sh docs/import/run-log.csv
git commit -m "feat(import): bulk import remaining leaves via run-all-stacks"
```

---

### Task 3.5: 전체 sanity plan

- [ ] **Step 1: 모든 leaf 에 대해 plan 재실행**

```bash
source scripts/import/env.sh
> /tmp/sanity-all.log
find azure -name main.tf -type f -not -path 'azure/ci/*' -not -path 'azure/script/*' | while read mf; do
  leaf=$(dirname "$mf")
  cd "$REPO_ROOT/$leaf"
  RES=$(terraform plan -no-color -detailed-exitcode 2>&1 | tail -3 || true)
  echo "=== $leaf ===" >> /tmp/sanity-all.log
  echo "$RES" >> /tmp/sanity-all.log
  cd "$REPO_ROOT"
done
```

`-detailed-exitcode`: 0=no changes, 1=error, 2=changes present.

- [ ] **Step 2: 차이 발견된 leaf 식별**

```bash
grep -B1 -E 'Plan: [^0]' /tmp/sanity-all.log | head -50
```

Expected: 빈 출력 (모든 leaf 가 no-change).

차이가 있는 leaf는 spec §6 절차로 조정 후 재apply.

- [ ] **Step 3: 보류 leaf 기록**

placeholder 가 남아 있어 import 불가능했던 leaf (예: 07.identity 의 group_object_id 4개) 를 `docs/import/run-log.csv` 또는 별도 섹션에 명시.

- [ ] **Step 4: 커밋**

```bash
git add docs/import/run-log.csv
git commit -m "feat(import): final sanity plan — all leaves no-change"
```

---

## Phase 4 — Variable 변경 검증

각 시나리오는 다음 공통 절차:
1. 변경 대상 leaf 식별
2. tfvars/locals 변경 (또는 환경변수)
3. `terraform plan -out=plan.out` 실행
4. plan 출력 검토: 의도된 형태인지 확인 (특히 replace 가 없는지)
5. `terraform apply plan.out`
6. Azure 측 반영 확인
7. plan 출력과 결과를 `docs/import/verify-results.md` 부록에 기록
8. 필요 시 변경 원복

### Task 4.1: 시나리오 1 — 태그 추가 (전체 leaf 영향)

**대상**: 모든 leaf의 공통 tags

- [ ] **Step 1: 검증용 태그 결정**

```
VerifyTag = "import-verify-2026-05-12"
```

- [ ] **Step 2: 단일 leaf 에서 먼저 검증 (hub-rg)**

`azure/hub/01.network/resource-group/hub-rg/terraform.tfvars` 의 `tags` 에 한 줄 추가:

```hcl
tags = {
  ManagedBy   = "Terraform"
  Environment = "dev"
  VerifyTag   = "import-verify-2026-05-12"
}
```

- [ ] **Step 3: plan 실행 및 출력 확인**

```bash
cd azure/hub/01.network/resource-group/hub-rg
terraform plan -out=plan.out
```

Expected:
```
~ tags = {
    ...
    + VerifyTag = "import-verify-2026-05-12"
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

`destroy` 가 보이면 즉시 중단하고 원인 분석.

- [ ] **Step 4: apply 및 Azure 확인**

```bash
terraform apply plan.out
az group show --name test-x-x-rg --query tags -o json
```

Expected: VerifyTag 가 보임.

- [ ] **Step 5: 변경 원복**

```bash
# tfvars에서 VerifyTag 라인 제거
sed -i.bak '/VerifyTag/d' terraform.tfvars
rm terraform.tfvars.bak
terraform apply -auto-approve
```

Expected: VerifyTag 가 제거됨.

- [ ] **Step 6: 결과 기록**

`docs/import/verify-results.md`:

```markdown
# Variable 변경 검증 결과

## 시나리오 1 — Tag 추가 (hub-rg)
- 변경: tags 에 VerifyTag 추가/제거
- 결과: in-place update 1회, replace 없음, Azure 반영 정상
- 실행일: 2026-05-12
```

- [ ] **Step 7: 커밋**

```bash
cd "$REPO_ROOT"
git add docs/import/verify-results.md
git commit -m "test(import): scenario 1 — tag add/remove on hub-rg verified"
```

---

### Task 4.2: 시나리오 2 — SKU 변경 (단일 VM)

**대상**: `azure/hub/06.compute/linux-monitoring-vm` 의 `vm_size`

- [ ] **Step 1: 현재 SKU 확인**

```bash
az vm show \
  --name <vm-name> \
  --resource-group test-x-x-rg \
  --query hardwareProfile.vmSize -o tsv
```

- [ ] **Step 2: in-place 가능한 인접 SKU 선정**

예: 현재 `Standard_B2s` → `Standard_B2ms`. azurerm provider는 vm_size 변경을 stop-start in-place 로 처리.

- [ ] **Step 3: tfvars 수정 후 plan**

`azure/hub/06.compute/linux-monitoring-vm/terraform.tfvars`:

```hcl
vm_size = "Standard_B2ms"  # 기존 Standard_B2s 에서 변경
```

```bash
cd azure/hub/06.compute/linux-monitoring-vm
terraform plan -out=plan.out
```

Expected:
```
~ size = "Standard_B2s" -> "Standard_B2ms"
Plan: 0 to add, 1 to change, 0 to destroy.
```

`Plan: ... 1 to destroy` 가 나오면 즉시 중단 (선택한 SKU 가 in-place 불가).

- [ ] **Step 4: apply 또는 보류 결정**

운영 영향이 있으므로 사용자 확인 후 `terraform apply plan.out`.

- [ ] **Step 5: Azure 확인 및 원복**

```bash
az vm show --name <vm-name> -g test-x-x-rg --query hardwareProfile.vmSize -o tsv
```

Expected: `Standard_B2ms`.

원복:
```bash
sed -i.bak 's/Standard_B2ms/Standard_B2s/' terraform.tfvars
rm terraform.tfvars.bak
terraform apply -auto-approve
```

- [ ] **Step 6: 결과 기록 및 커밋**

`docs/import/verify-results.md` 에 시나리오 2 행 추가.

```bash
cd "$REPO_ROOT"
git add docs/import/verify-results.md
git commit -m "test(import): scenario 2 — VM SKU in-place change verified"
```

---

### Task 4.3: 시나리오 3 — NSG 규칙 추가

**대상**: `azure/hub/01.network/security-group/network-security-rule/<one-leaf>`

- [ ] **Step 1: 대상 NSG 및 규칙 선정**

```bash
ls azure/hub/01.network/security-group/network-security-rule/
```

작은 NSG 1개 (예: `monitoring-vm-snet-nsg` 등) 선택. tfvars 의 rule 리스트에 임시 규칙 1개 추가.

- [ ] **Step 2: tfvars 수정**

`<선택한 leaf>/terraform.tfvars` 에 규칙 추가:

```hcl
rules = [
  # 기존 규칙들...
  {
    name                       = "verify-temp-deny-22"
    priority                   = 4090
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
]
```

- [ ] **Step 3: plan 실행**

```bash
cd <선택한 leaf>
terraform plan -out=plan.out
```

Expected:
```
+ azurerm_network_security_rule.this["verify-temp-deny-22"]
Plan: 1 to add, 0 to change, 0 to destroy.
```

- [ ] **Step 4: apply, Azure 확인, 원복**

```bash
terraform apply plan.out
az network nsg rule show --name verify-temp-deny-22 \
  --nsg-name <nsg-name> -g test-x-x-rg --query '{name:name, priority:priority}' -o table
```

원복:
```bash
# tfvars에서 verify-temp-deny-22 블록 제거
$EDITOR terraform.tfvars
terraform apply -auto-approve
```

- [ ] **Step 5: 결과 기록 및 커밋**

```bash
cd "$REPO_ROOT"
git add docs/import/verify-results.md
git commit -m "test(import): scenario 3 — NSG rule add/remove verified"
```

---

### Task 4.4: 시나리오 4 — CIDR 변경 (빈 subnet)

**대상**: 사용 중이지 않은 subnet 1개 (보유 자원 영향 최소화)

- [ ] **Step 1: 빈 subnet 식별**

```bash
# subnet 의 ipConfigurations 가 비어 있는 것을 찾음
az network vnet subnet list -g test-x-x-rg --vnet-name test-x-x-vnet \
  --query "[?ipConfigurations==null].{name:name, prefix:addressPrefix}" -o table
```

- [ ] **Step 2: 대상 subnet leaf 식별**

```bash
grep -RIl '<선택한 subnet 이름>' azure/hub/01.network/subnet/
```

- [ ] **Step 3: tfvars 의 CIDR 마지막 비트 변경**

예: `10.0.99.0/24` → `10.0.98.0/24` (충돌 없는 빈 대역)

미리 충돌 확인:
```bash
az network vnet subnet list -g test-x-x-rg --vnet-name test-x-x-vnet \
  --query "[].addressPrefix" -o tsv
```

- [ ] **Step 4: plan 실행 및 검토**

```bash
cd azure/hub/01.network/subnet/<leaf>
terraform plan -out=plan.out
```

Expected (위험):
- `~ address_prefixes = [...] -> [...]` 의 in-place update 면 OK
- `-/+ destroy and then create` 면 STOP (subnet replace는 보유 NIC 영향 가능)

- [ ] **Step 5: apply 또는 보류**

in-place 면 `terraform apply plan.out`. replace 면 보류하고 결과 기록.

- [ ] **Step 6: 원복 및 커밋**

```bash
# tfvars 원복 후 apply
terraform apply -auto-approve
cd "$REPO_ROOT"
git add docs/import/verify-results.md
git commit -m "test(import): scenario 4 — subnet CIDR change verified"
```

---

### Task 4.5: 최종 정리

- [ ] **Step 1: imports.tf 잔재 확인**

```bash
find azure -name imports.tf -type f
```

Expected: 출력 없음. 남아 있으면 정상적으로 제거되지 않은 것 — sanity plan 실행 후 제거.

- [ ] **Step 2: gitignore 검토**

`docs/import/inventory.json` 이 gitignore 에 있는지 확인. `plan.out` 도 추가:

```bash
grep -q 'plan.out' .gitignore || echo 'plan.out' >> .gitignore
git diff .gitignore
```

- [ ] **Step 3: 최종 commit**

```bash
git add .gitignore
git commit -m "chore(import): finalize import workflow — gitignore hardening"
```

- [ ] **Step 4: PR 또는 브랜치 정리**

`finishing-a-development-branch` 스킬로 진행 결정.

---

## Phase 5 — 문서화 보강 (선택)

### Task 5.1: DEPLOY-GUIDE에 import 절차 링크

- [ ] **Step 1: DEPLOY-GUIDE.md 에 import 섹션 추가**

`DEPLOY-GUIDE.md` 의 적절한 위치 (사전 조건 다음) 에 추가:

```markdown
## 기존 Azure 환경 Import

이미 운영 중인 Azure 리소스를 본 IaC 코드로 가져오려면
`docs/superpowers/plans/2026-05-12-azure-import-and-verify-plan.md` 를 따른다.
```

- [ ] **Step 2: 커밋**

```bash
git add DEPLOY-GUIDE.md
git commit -m "docs(deploy): link azure import & verify plan from DEPLOY-GUIDE"
```

---

## 부록: 자주 발생하는 plan diff 패턴과 해결

| diff 항목 | 원인 | 해결 |
|---|---|---|
| `~ tags` 의 추가 키 | 운영 리소스에 코드 미정의 태그 | tfvars 의 tags 에 동일 키 추가 |
| `~ enable_telemetry: true -> false` | 모듈 default 와 실 리소스 차이 | main.tf 에 `enable_telemetry = false` 명시 |
| `~ name: "abc" -> "test-x-x-abc"` | local.name_prefix 불일치 | tfvars 의 project_name 또는 locals 수정 |
| `-/+ replace` (force-new) | 변경 불가 속성 (예: location, size 일부) | 코드를 실 리소스 값에 맞추거나 보류 |
| `+ azurerm_*` (sub-resource) | 모듈이 default로 만드는 리소스가 운영에 없음 | tfvars 의 feature flag로 비활성화 (예: `enable_diag = false`) |
| `- azurerm_*` (sub-resource) | 운영에 있는데 모듈이 안 만드는 리소스 | 해당 sub-resource 도 import 추가 또는 별도 leaf 로 분리 |

---

## 검증 게이트 요약

| Phase | 게이트 |
|---|---|
| 0 | env.sh OK, inventory.csv ≥ 50행, leaf-to-resource-map.csv 헤더+행 채움, pilot 행 검증 |
| 1 | hub-rg plan no-diff 후 apply, state list 확인, sanity plan 0 changes |
| 2 | 9개 대표 leaf 모두 apply 성공, address-catalog.md 작성 |
| 3 | run-all-stacks 실행 후 run-log.csv 의 status 가 모두 success 또는 명시적 보류 |
| 4 | 시나리오 1~4 의 apply 결과 Azure 반영 확인 후 원복 |
