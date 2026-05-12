# Hub/Spoke 2-구독 분리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `azure/` 폴더의 60개 leaf를 `azure/hub/`와 `azure/spoke/` 두 트리로 물리 분리하면서 state storage·backend 변수·subscription ID 주입 방식·AVM 모듈 source URL을 모두 hub/spoke 2-구독 운영에 맞게 일괄 변환한다.

**Architecture:** apply 전 상태이므로 state migration은 없다. 작업은 (a) git mv로 폴더 재배치, (b) Python 스크립트로 main.tf/data.tf/variables.tf/tfvars 일괄 변환, (c) `terraform validate`로 정합성 검증의 3단계로 구성된다. 모든 변환 스크립트는 repo의 `scripts/migrate/` 하위에 두며 idempotent하게 작성한다.

**Tech Stack:** Terraform (azurerm provider), Python 3 (표준 라이브러리만), bash, sed, git

**Spec:** `docs/superpowers/specs/2026-05-11-hub-spoke-subscription-split-design.md`

---

## File Structure

### 새로 생성

- `azure/hub/` 트리 — 37 leaf
- `azure/spoke/` 트리 — 23 leaf
- 각 leaf에 `backend.hcl.example`
- `scripts/migrate/leaf-mapping.tsv` — leaf 분류 매핑 데이터 (단일 source of truth)
- `scripts/migrate/mv-leaves.sh` — git mv 일괄 실행
- `scripts/migrate/migrate-module-sources.sh` — main.tf의 GitHub URL을 GitLab URL로 sed 치환
- `scripts/migrate/migrate-data-tf.py` — data.tf의 state key + backend var 일괄 변환
- `scripts/migrate/migrate-variables-tf.py` — variables.tf의 backend_* 변수 교체
- `scripts/migrate/migrate-tfvars.py` — terraform.tfvars / .example 정리
- `scripts/migrate/gen-backend-hcl-example.py` — backend.hcl.example 생성
- `scripts/migrate/verify.sh` — 검증 명령 모음

### 수정

- `.gitignore` — `**/backend.hcl` 추가
- 60개 leaf의 `main.tf` — module source URL 1줄 치환
- 60개 leaf의 `data.tf` — state key 경로 + backend 변수명 치환
- 60개 leaf의 `variables.tf` — backend_* 변수 선언 교체
- 60개 leaf의 `terraform.tfvars`, `terraform.tfvars.example` — subscription_id/backend_* 라인 제거 + hub/spoke backend 값 추가

### 삭제

- `azure/ci/` (빈 디렉터리)
- `azure/script/` (빈 디렉터리)
- `azure/` 하위의 기존 9개 스택 디렉터리 (git mv 결과로 비워짐)

---

## Pre-flight: 미커밋 변경 처리

현재 작업 트리에 ~912개의 미커밋 변경이 있다 (`git status` 기준 — `azure/dev/` 정리, NSR 삭제, dns-private-resolver-inbound-endpoint 삭제 등). 본 plan은 **깨끗한 트리**에서 시작해야 변환 결과를 추적할 수 있다.

- [ ] **Pre-flight Step 1: git status 확인**

Run: `git -C /Users/mzs02-andy/Projects/mz_external/terraform-iac status --short | wc -l`
Expected: 약 900+ 줄

- [ ] **Pre-flight Step 2: 사용자 결정 받기**

다음 중 하나를 사용자에게 선택받아 실행:
- (a) 미커밋 변경을 별도 commit으로 정리 (권장)
- (b) `git stash`로 임시 보관 후 작업 종료 후 복원
- (c) 미커밋 변경을 버리고 시작 (`git checkout -- .` — 작업 손실 위험)

본 plan은 (a)를 가정한다. (a) 선택 시 별도 commit 메시지로 "chore: pre-split workspace cleanup" 같은 단일 커밋을 만든다.

- [ ] **Pre-flight Step 3: 깨끗한 상태 확인**

Run: `git -C /Users/mzs02-andy/Projects/mz_external/terraform-iac status --short`
Expected: 빈 출력

---

## Task 1: Leaf 분류 매핑 파일 작성

**Files:**
- Create: `scripts/migrate/leaf-mapping.tsv`

이 파일은 이후 모든 자동화 스크립트의 단일 source of truth다. 형식: `<현재 leaf 경로>\t<hub|spoke>`. 현재 경로는 `azure/` 기준 상대 경로.

- [ ] **Step 1.1: scripts/migrate/ 디렉터리 생성**

Run: `mkdir -p scripts/migrate`

- [ ] **Step 1.2: 매핑 파일 작성**

Create `scripts/migrate/leaf-mapping.tsv` with exactly these 60 lines (tab-separated):

```
01.network/dns/dns-private-resolver/hub	hub
01.network/dns/private-dns-zone-vnet-link/hub-blob-to-hub-vnet	hub
01.network/dns/private-dns-zone-vnet-link/hub-openai-to-hub-vnet	hub
01.network/dns/private-dns-zone-vnet-link/hub-vault-to-hub-vnet	hub
01.network/dns/private-dns-zone-vnet-link/spoke-azure-api-to-spoke-vnet	spoke
01.network/dns/private-dns-zone-vnet-link/spoke-cognitiveservices-to-spoke-vnet	spoke
01.network/dns/private-dns-zone-vnet-link/spoke-ml-to-spoke-vnet	spoke
01.network/dns/private-dns-zone-vnet-link/spoke-notebooks-to-spoke-vnet	spoke
01.network/dns/private-dns-zone-vnet-link/spoke-openai-to-spoke-vnet	spoke
01.network/dns/private-dns-zone/hub-blob	hub
01.network/dns/private-dns-zone/hub-vault	hub
01.network/dns/private-dns-zone/spoke-azure-api	spoke
01.network/dns/private-dns-zone/spoke-cognitiveservices	spoke
01.network/dns/private-dns-zone/spoke-ml	spoke
01.network/dns/private-dns-zone/spoke-notebooks	spoke
01.network/dns/private-dns-zone/spoke-openai	spoke
01.network/public-ip/hub-vpn-gateway	hub
01.network/resource-group/hub-rg	hub
01.network/resource-group/spoke-rg	spoke
01.network/route/hub-route-default	hub
01.network/route/spoke-route-default	spoke
01.network/security-group/application-security-group/keyvault-clients	hub
01.network/security-group/application-security-group/vm-allowed-clients	hub
01.network/security-group/network-security-group/hub-monitoring-vm	hub
01.network/security-group/network-security-group/hub-pep	hub
01.network/security-group/network-security-group/keyvault-standalone	hub
01.network/security-group/network-security-group/spoke-pep	spoke
01.network/security-group/security-policy/hub-sg-policy-default	hub
01.network/security-group/security-policy/spoke-sg-policy-default	spoke
01.network/subnet/hub-appgateway-subnet	hub
01.network/subnet/hub-azurefirewall-management-subnet	hub
01.network/subnet/hub-azurefirewall-subnet	hub
01.network/subnet/hub-dnsresolver-inbound-subnet	hub
01.network/subnet/hub-gateway-subnet	hub
01.network/subnet/hub-monitoring-vm-subnet	hub
01.network/subnet/hub-pep-subnet	hub
01.network/subnet/spoke-apim-subnet	spoke
01.network/subnet/spoke-pep-subnet	spoke
01.network/virtual-network-gateway/hub-vpn-gateway	hub
01.network/vnet/hub-vnet	hub
01.network/vnet/spoke-vnet	spoke
02.storage/monitoring	hub
03.shared-services/log-analytics	hub
03.shared-services/log-analytics-workspace	hub
03.shared-services/shared	hub
04.apim/workload	spoke
05.ai-services/workload	spoke
06.compute/linux-monitoring-vm	hub
06.compute/windows-example	hub
07.identity/group-membership/admin-core	hub
07.identity/group-membership/ai-developer-core	hub
08.rbac/authorization/hub-assignments	hub
08.rbac/authorization/spoke-assignments	spoke
08.rbac/group/admin-hub-scope	hub
08.rbac/group/ai-developer-spoke-scope	spoke
08.rbac/principal/hub-assignments	hub
08.rbac/principal/spoke-assignments	spoke
09.connectivity/diagnostics/hub	hub
09.connectivity/peering/hub-to-spoke	hub
09.connectivity/peering/spoke-to-hub	spoke
```

- [ ] **Step 1.3: 매핑 파일 카운트 검증**

Run:
```bash
wc -l scripts/migrate/leaf-mapping.tsv
awk -F'\t' '{print $2}' scripts/migrate/leaf-mapping.tsv | sort | uniq -c
```
Expected:
```
60 scripts/migrate/leaf-mapping.tsv
  37 hub
  23 spoke
```

- [ ] **Step 1.4: 실제 leaf와 매핑 일치 검증**

Run:
```bash
find azure -mindepth 2 -name main.tf -not -path "*/modules/*" -not -path "azure/dev/*" -not -path "azure-*" | sed 's|^azure/||;s|/main.tf$||' | sort > /tmp/actual-leaves.txt
awk -F'\t' '{print $1}' scripts/migrate/leaf-mapping.tsv | sort > /tmp/mapped-leaves.txt
diff /tmp/actual-leaves.txt /tmp/mapped-leaves.txt
```
Expected: 빈 출력 (양쪽이 정확히 일치)

- [ ] **Step 1.5: commit**

```bash
git add scripts/migrate/leaf-mapping.tsv
git commit -m "chore(migrate): hub/spoke 분리용 leaf 분류 매핑 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: .gitignore 갱신 + 새 디렉터리 골격

**Files:**
- Modify: `.gitignore`

- [ ] **Step 2.1: .gitignore에 backend.hcl 추가**

`.gitignore` 끝에 다음 블록 추가 (이미 있으면 skip):

```gitignore

# Backend 설정 (외부 주입, .example만 추적)
**/backend.hcl
```

- [ ] **Step 2.2: 새 디렉터리 골격 생성**

Run: `mkdir -p azure/hub azure/spoke`

(빈 디렉터리는 git이 추적 안 하므로 별도 placeholder 불필요. Task 3의 mv 실행으로 자동으로 내용물이 채워진다.)

- [ ] **Step 2.3: commit**

```bash
git add .gitignore
git commit -m "chore: backend.hcl을 gitignore에 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: git mv로 60개 leaf 재배치

**Files:**
- Create: `scripts/migrate/mv-leaves.sh`

매핑 tsv를 읽어 `git mv azure/<src> azure/<hub|spoke>/<src>`를 일괄 실행한다.

- [ ] **Step 3.1: mv 스크립트 작성**

Create `scripts/migrate/mv-leaves.sh`:

```bash
#!/usr/bin/env bash
# 매핑 tsv를 읽어 git mv로 leaf를 hub/spoke 트리로 재배치
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
MAPPING="${REPO_ROOT}/scripts/migrate/leaf-mapping.tsv"

if [[ ! -f "$MAPPING" ]]; then
  echo "ERROR: mapping not found at $MAPPING" >&2
  exit 1
fi

cd "$REPO_ROOT"

# 각 leaf 이동
while IFS=$'\t' read -r src_path trunk; do
  src="azure/${src_path}"
  dst_parent="azure/${trunk}/$(dirname "$src_path")"
  dst="azure/${trunk}/${src_path}"

  if [[ ! -d "$src" ]]; then
    echo "SKIP (already moved or missing): $src"
    continue
  fi

  mkdir -p "$dst_parent"
  git mv "$src" "$dst"
  echo "MOVED: $src -> $dst"
done < "$MAPPING"
```

- [ ] **Step 3.2: 스크립트에 실행 권한**

Run: `chmod +x scripts/migrate/mv-leaves.sh`

- [ ] **Step 3.3: 실행**

Run: `bash scripts/migrate/mv-leaves.sh`
Expected: 60줄의 `MOVED: azure/<src> -> azure/<hub|spoke>/<src>` 출력

- [ ] **Step 3.4: 빈 카테고리 디렉터리 정리**

Run:
```bash
find azure -mindepth 1 -maxdepth 4 -type d -empty -not -path "azure/hub*" -not -path "azure/spoke*" -delete
ls azure/
```
Expected: `hub  spoke` (그리고 `ci`, `script` 빈 폴더가 남아있으면 다음 step에서 제거)

- [ ] **Step 3.5: azure/ci, azure/script 빈 폴더 제거**

Run:
```bash
rmdir azure/ci azure/script 2>/dev/null || true
ls azure/
```
Expected: `hub  spoke` 만 출력

- [ ] **Step 3.6: 결과 카운트 검증**

Run:
```bash
find azure/hub -mindepth 1 -name main.tf -not -path "*/modules/*" | wc -l
find azure/spoke -mindepth 1 -name main.tf -not -path "*/modules/*" | wc -l
```
Expected:
```
37
23
```

- [ ] **Step 3.7: commit**

```bash
git add -A scripts/migrate/mv-leaves.sh azure/
git commit -m "refactor(azure): 60개 leaf를 hub/spoke 트리로 재배치

azure/01.network/ 등 9개 스택을 azure/hub/<stack>/ 와 azure/spoke/<stack>/
두 트리로 git mv. 빈 azure/ci, azure/script 폴더 제거.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: AVM 모듈 source URL을 GitLab으로 일괄 치환

**Files:**
- Create: `scripts/migrate/migrate-module-sources.sh`
- Modify: 60개 leaf의 `main.tf` (모듈 source 라인이 있는 leaf만)

- [ ] **Step 4.1: 치환 스크립트 작성**

Create `scripts/migrate/migrate-module-sources.sh`:

```bash
#!/usr/bin/env bash
# main.tf의 GitHub kimchibee 모듈 URL을 내부 GitLab URL로 sed 치환
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

OLD_PREFIX='git::https://github.com/kimchibee/terraform-modules.git//avm/'
NEW_PREFIX='git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/'

# sed에 인자로 줄 변환 식. submodule 패턴부터 처리하고 그 다음 일반 패턴.
# 1) virtualnetwork v0.17.1 submodule: subnet, peering
# 2) virtualnetwork v0.7.1 (부모)
# 3) privatednszone submodule
# 4) privatednszone (부모)
# 5) 그 외 모듈: 버전 접미사 없음, -main.git 부착

# Python으로 더 안전하게 처리 (sed 다중 alternation 회피)
python3 <<'PY'
import re
from pathlib import Path

OLD_RE = re.compile(
    r'git::https://github\.com/kimchibee/terraform-modules\.git//avm/'
    r'(?P<mod>terraform-azurerm-avm-[a-z0-9-]+?)'
    r'(?P<ver>-v\d+\.\d+\.\d+)?'
    r'(?P<sub>/modules/[a-z0-9_]+)?'
    r'\?ref=main'
)
NEW_PREFIX = 'git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/'

def replace(m):
    mod = m.group('mod')   # e.g. terraform-azurerm-avm-res-resources-resourcegroup
    sub = m.group('sub')   # e.g. /modules/subnet or None
    new_repo = f'{mod}-main.git'
    suffix = f'//{sub.lstrip("/")}' if sub else ''
    return f'{NEW_PREFIX}{new_repo}{suffix}?ref=main'

changed = 0
for path in Path('azure').rglob('main.tf'):
    text = path.read_text()
    new_text, n = OLD_RE.subn(replace, text)
    if n > 0:
        path.write_text(new_text)
        print(f'{n:>2}  {path}')
        changed += n
print(f'\nTotal lines changed: {changed}')
PY
```

- [ ] **Step 4.2: 실행**

Run:
```bash
chmod +x scripts/migrate/migrate-module-sources.sh
bash scripts/migrate/migrate-module-sources.sh
```
Expected: 약 50+ 줄의 `<n> azure/.../main.tf` 출력, 마지막에 `Total lines changed: 50+`

- [ ] **Step 4.3: kimchibee 잔여 확인**

Run: `grep -r "kimchibee" azure/ || echo "OK: no kimchibee references"`
Expected: `OK: no kimchibee references`

- [ ] **Step 4.4: 새 URL 정합성 sample 확인**

Run: `grep -r "source\s*=\s*\"git::https://dev-gitlab" azure/ | head -3`
Expected: 3줄의 새 GitLab URL 형식 출력. 예:
```
azure/hub/01.network/resource-group/hub-rg/main.tf:  source = "git::https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/terraform-azurerm-avm-res-resources-resourcegroup-main.git?ref=main"
```

- [ ] **Step 4.5: submodule 변환 확인**

Run: `grep -r "//modules/" azure/ | grep "dev-gitlab" | head -3`
Expected: 3줄의 submodule URL. 예:
```
azure/hub/01.network/subnet/hub-vnet-subnet/main.tf:  source = "git::https://dev-gitlab.kis.zone/.../terraform-azurerm-avm-res-network-virtualnetwork-main.git//modules/subnet?ref=main"
```

- [ ] **Step 4.6: commit**

```bash
git add scripts/migrate/migrate-module-sources.sh azure/
git commit -m "refactor(azure): AVM 모듈 source를 내부 GitLab으로 마이그레이션

github.com/kimchibee/terraform-modules.git//avm/<MOD>(-vX.Y.Z)?(/modules/<SUB>)?
→ dev-gitlab.kis.zone/.../azure/azure/<MOD>-main.git(//modules/<SUB>)?

버전 접미사(-v0.7.1, -v0.17.1) 제거, -main.git 부착. submodule 경로는
.git//modules/<sub> 형태로 유지. ref=main 유지.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: data.tf의 state key 경로 + backend 변수 치환

**Files:**
- Create: `scripts/migrate/migrate-data-tf.py`
- Modify: 60개 leaf의 `data.tf`

각 leaf의 `data.tf`에는 0개 이상의 `terraform_remote_state` 블록이 있다. 각 블록의:
1. `key = "azure/dev/<stack>/..."` → 매핑표 기준으로 `azure/dev/hub/<stack>/...` 또는 `azure/dev/spoke/<stack>/...`로 변환
2. `var.backend_resource_group_name` / `var.backend_storage_account_name` / `var.backend_container_name` → 같은 블록의 key가 hub면 `var.hub_backend_*`, spoke면 `var.spoke_backend_*`로 변환

- [ ] **Step 5.1: 변환 스크립트 작성**

Create `scripts/migrate/migrate-data-tf.py`:

```python
#!/usr/bin/env python3
"""data.tf 일괄 변환: state key 경로에 hub/spoke 삽입 + backend var를 hub_/spoke_ 짝으로 치환."""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAPPING_FILE = REPO_ROOT / 'scripts' / 'migrate' / 'leaf-mapping.tsv'

# leaf 경로 → trunk(hub|spoke)
LEAF_TO_TRUNK = {}
with MAPPING_FILE.open() as f:
    for line in f:
        line = line.rstrip('\n')
        if not line or line.startswith('#'):
            continue
        src, trunk = line.split('\t')
        LEAF_TO_TRUNK[src] = trunk

def leaf_path_from_key(key_value):
    """key = 'azure/dev/<stack>/.../terraform.tfstate' → '<stack>/...' (leaf 상대 경로)"""
    m = re.match(r'azure/dev/(.+)/terraform\.tfstate$', key_value)
    if not m:
        return None
    return m.group(1)

def trunk_for_key(key_value):
    leaf = leaf_path_from_key(key_value)
    if leaf is None:
        return None
    return LEAF_TO_TRUNK.get(leaf)

BLOCK_RE = re.compile(
    r'(data\s+"terraform_remote_state"\s+"[^"]+"\s*\{[^}]*?\})',
    re.DOTALL,
)
KEY_RE = re.compile(r'key\s*=\s*"(azure/dev/[^"]+)"')
RG_RE  = re.compile(r'\bvar\.backend_resource_group_name\b')
SA_RE  = re.compile(r'\bvar\.backend_storage_account_name\b')
CN_RE  = re.compile(r'\bvar\.backend_container_name\b')

def transform_block(block):
    key_match = KEY_RE.search(block)
    if not key_match:
        return block, None
    key_value = key_match.group(1)
    trunk = trunk_for_key(key_value)
    if trunk is None:
        print(f'  WARN: cannot classify key {key_value!r}', file=sys.stderr)
        return block, None

    # 1) key 경로에 trunk 삽입
    leaf = leaf_path_from_key(key_value)
    new_key = f'azure/dev/{trunk}/{leaf}/terraform.tfstate'
    block = block.replace(key_value, new_key)

    # 2) backend var 치환 (해당 블록 내부에서만)
    block = RG_RE.sub(f'var.{trunk}_backend_resource_group_name', block)
    block = SA_RE.sub(f'var.{trunk}_backend_storage_account_name', block)
    block = CN_RE.sub(f'var.{trunk}_backend_container_name', block)

    return block, trunk

def transform_file(path):
    text = path.read_text()
    new_text = text
    offset = 0
    trunks_seen = set()
    for m in BLOCK_RE.finditer(text):
        block = m.group(1)
        new_block, trunk = transform_block(block)
        if trunk:
            trunks_seen.add(trunk)
        if new_block != block:
            start = m.start(1) + offset
            end   = m.end(1)   + offset
            new_text = new_text[:start] + new_block + new_text[end:]
            offset += len(new_block) - len(block)
    if new_text != text:
        path.write_text(new_text)
    return trunks_seen

total_files = 0
for path in sorted((REPO_ROOT / 'azure').rglob('data.tf')):
    trunks = transform_file(path)
    if trunks:
        rel = path.relative_to(REPO_ROOT)
        print(f'  {",".join(sorted(trunks))}  {rel}')
        total_files += 1

print(f'\nTransformed {total_files} data.tf files')
```

- [ ] **Step 5.2: 실행**

Run: `python3 scripts/migrate/migrate-data-tf.py`
Expected: 약 50+ 줄의 `  hub|spoke|hub,spoke  azure/.../data.tf` 출력. 마지막에 `Transformed N data.tf files`

- [ ] **Step 5.3: 잔여 검증**

Run:
```bash
grep -rE 'key\s*=\s*"azure/dev/[^h][^u][^b]' azure/ | grep -v "azure/dev/hub\|azure/dev/spoke" || echo "OK: no legacy key prefixes"
grep -rE '\bvar\.backend_(resource_group_name|storage_account_name|container_name)\b' azure/ --include='data.tf' || echo "OK: no legacy backend vars in data.tf"
```
Expected: 두 명령 모두 `OK: ...` 출력

- [ ] **Step 5.4: 변환 sample 확인**

Run: `grep -A6 'terraform_remote_state' azure/spoke/09.connectivity/peering/spoke-to-hub/data.tf | head -20`
Expected: hub 참조 블록은 `var.hub_backend_*` + `key = "azure/dev/hub/01.network/vnet/hub-vnet/terraform.tfstate"` 형태로 확인됨

- [ ] **Step 5.5: commit**

```bash
git add scripts/migrate/migrate-data-tf.py azure/
git commit -m "refactor(azure): data.tf state key에 hub/spoke 삽입 + backend var 분리

각 terraform_remote_state 블록의 key를 azure/dev/{hub|spoke}/<stack>/... 형태로
변환하고, 같은 블록 내 var.backend_* 참조를 leaf 분류에 따라 var.hub_backend_*
또는 var.spoke_backend_*로 치환.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: variables.tf의 backend_* 변수 선언 교체

**Files:**
- Create: `scripts/migrate/migrate-variables-tf.py`
- Modify: 60개 leaf의 `variables.tf`

각 leaf의 `variables.tf`에서 기존 `backend_resource_group_name/storage_account_name/container_name` 3개 선언을 제거하고, 그 leaf의 `data.tf`에 등장하는 `hub_backend_*` 또는 `spoke_backend_*` 변수만 추가한다.

- [ ] **Step 6.1: 변환 스크립트 작성**

Create `scripts/migrate/migrate-variables-tf.py`:

```python
#!/usr/bin/env python3
"""variables.tf 갱신: 기존 backend_* 선언 제거, data.tf에 실제 등장한 hub_/spoke_backend_* 선언 추가."""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

OLD_VAR_RE = re.compile(
    r'(?:^|\n)\s*variable\s+"backend_(?:resource_group_name|storage_account_name|container_name)"\s*\{[^}]*\}',
    re.DOTALL,
)

NEW_VAR_TEMPLATE = {
    'hub': '''
variable "hub_backend_resource_group_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "hub_backend_storage_account_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage account 이름"
}

variable "hub_backend_container_name" {
  type        = string
  description = "Hub 구독의 Terraform state storage container 이름"
}
''',
    'spoke': '''
variable "spoke_backend_resource_group_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage가 위치한 resource group 이름"
}

variable "spoke_backend_storage_account_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage account 이름"
}

variable "spoke_backend_container_name" {
  type        = string
  description = "Spoke 구독의 Terraform state storage container 이름"
}
''',
}

def trunks_used_by_data_tf(data_tf):
    if not data_tf.exists():
        return set()
    text = data_tf.read_text()
    trunks = set()
    if 'var.hub_backend_' in text:
        trunks.add('hub')
    if 'var.spoke_backend_' in text:
        trunks.add('spoke')
    return trunks

total = 0
for variables_tf in sorted((REPO_ROOT / 'azure').rglob('variables.tf')):
    leaf_dir = variables_tf.parent
    data_tf = leaf_dir / 'data.tf'

    text = variables_tf.read_text()
    new_text = OLD_VAR_RE.sub('', text).rstrip() + '\n'

    trunks = trunks_used_by_data_tf(data_tf)
    appended = []
    for trunk in sorted(trunks):
        new_text = new_text.rstrip() + '\n' + NEW_VAR_TEMPLATE[trunk]
        appended.append(trunk)

    if new_text != text:
        variables_tf.write_text(new_text)
        rel = variables_tf.relative_to(REPO_ROOT)
        appended_str = ','.join(appended) if appended else '-'
        print(f'  removed-old / added={appended_str}  {rel}')
        total += 1

print(f'\nTransformed {total} variables.tf files')
```

- [ ] **Step 6.2: 실행**

Run: `python3 scripts/migrate/migrate-variables-tf.py`
Expected: 약 50+ 줄 출력, 마지막에 `Transformed N variables.tf files`

- [ ] **Step 6.3: 잔여 검증**

Run:
```bash
grep -rE 'variable\s+"backend_(resource_group_name|storage_account_name|container_name)"' azure/ --include='variables.tf' || echo "OK: no legacy backend var declarations"
```
Expected: `OK: no legacy backend var declarations`

- [ ] **Step 6.4: sample 확인**

Run: `tail -25 azure/hub/01.network/vnet/hub-vnet/variables.tf`
Expected: `hub_backend_resource_group_name`, `hub_backend_storage_account_name`, `hub_backend_container_name` 3개 선언이 보임

- [ ] **Step 6.5: commit**

```bash
git add scripts/migrate/migrate-variables-tf.py azure/
git commit -m "refactor(azure): variables.tf의 backend_* 선언을 hub/spoke 2세트로 교체

기존 backend_resource_group_name/storage_account_name/container_name 3개
선언을 제거하고, 해당 leaf의 data.tf에 실제로 등장하는 hub_backend_*
또는 spoke_backend_* 변수만 추가.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: terraform.tfvars / .example 정리

**Files:**
- Create: `scripts/migrate/migrate-tfvars.py`
- Modify: 60개 leaf의 `terraform.tfvars`와 `terraform.tfvars.example`

각 leaf의 tfvars 파일에서:
1. `hub_subscription_id`, `spoke_subscription_id` 라인 제거 (환경변수로 이관)
2. 기존 `backend_resource_group_name/storage_account_name/container_name` 라인 제거
3. variables.tf에 hub_backend_* 변수가 있으면 hub_backend 값을 추가, spoke_backend_*가 있으면 spoke_backend 값 추가
4. `.example`만 상단에 환경변수 사용법 주석 추가

본 plan은 hub state storage가 기존(`tfstatea9911`)이고, spoke state storage 이름은 placeholder(`<SPOKE_STATE_STORAGE_ACCOUNT>`)로 둔다 (운영자가 실제 생성 후 채움).

- [ ] **Step 7.1: 변환 스크립트 작성**

Create `scripts/migrate/migrate-tfvars.py`:

```python
#!/usr/bin/env python3
"""terraform.tfvars / .example 일괄 정리."""
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# 제거할 라인 (key 단위)
REMOVE_KEYS = [
    'hub_subscription_id',
    'spoke_subscription_id',
    'backend_resource_group_name',
    'backend_storage_account_name',
    'backend_container_name',
]

# 추가할 hub/spoke backend 값 (.tfvars 기준 — 운영자가 실제 값을 채움)
HUB_BACKEND_BLOCK = '''
hub_backend_resource_group_name  = "terraform-state-rg"
hub_backend_storage_account_name = "tfstatea9911"
hub_backend_container_name       = "tfstate"
'''.strip()

SPOKE_BACKEND_BLOCK = '''
spoke_backend_resource_group_name  = "<SPOKE_STATE_RG>"
spoke_backend_storage_account_name = "<SPOKE_STATE_STORAGE_ACCOUNT>"
spoke_backend_container_name       = "tfstate"
'''.strip()

EXAMPLE_HEADER = '''# terraform.tfvars.example
#
# 사용법:
#   1) 이 파일을 terraform.tfvars로 복사
#   2) <PLACEHOLDER> 부분을 실제 값으로 교체
#   3) hub_subscription_id, spoke_subscription_id는 본 파일에 두지 않음 —
#      환경변수로 주입: export TF_VAR_hub_subscription_id=...
#                       export TF_VAR_spoke_subscription_id=...
#   4) backend 설정은 별도 backend.hcl 파일을 사용:
#      terraform init -backend-config=backend.hcl
#
'''

def remove_keys(text, keys):
    lines = text.splitlines(keepends=True)
    out = []
    for line in lines:
        stripped = line.lstrip()
        if any(stripped.startswith(f'{k} ') or stripped.startswith(f'{k}\t') or stripped.startswith(f'{k}=')
               for k in keys):
            continue
        out.append(line)
    return ''.join(out)

def trunks_used(leaf_dir):
    variables_tf = leaf_dir / 'variables.tf'
    if not variables_tf.exists():
        return set()
    text = variables_tf.read_text()
    trunks = set()
    if 'hub_backend_resource_group_name' in text:
        trunks.add('hub')
    if 'spoke_backend_resource_group_name' in text:
        trunks.add('spoke')
    return trunks

def process(path, is_example):
    leaf_dir = path.parent
    text = path.read_text()
    new_text = remove_keys(text, REMOVE_KEYS)

    # backend 블록 추가
    trunks = trunks_used(leaf_dir)
    additions = []
    if 'hub' in trunks:
        additions.append(HUB_BACKEND_BLOCK)
    if 'spoke' in trunks:
        additions.append(SPOKE_BACKEND_BLOCK)

    if additions:
        new_text = new_text.rstrip() + '\n\n' + '\n\n'.join(additions) + '\n'

    if is_example:
        new_text = EXAMPLE_HEADER + new_text.lstrip()

    if new_text != text:
        path.write_text(new_text)
        return True
    return False

total = 0
for path in sorted((REPO_ROOT / 'azure').rglob('terraform.tfvars*')):
    if path.name not in ('terraform.tfvars', 'terraform.tfvars.example'):
        continue
    is_example = path.name == 'terraform.tfvars.example'
    if process(path, is_example):
        rel = path.relative_to(REPO_ROOT)
        print(f'  {"EXAMPLE" if is_example else "TFVARS "}  {rel}')
        total += 1

print(f'\nTransformed {total} tfvars files')
```

- [ ] **Step 7.2: 실행**

Run: `python3 scripts/migrate/migrate-tfvars.py`
Expected: 약 100+ 줄 (각 leaf의 .tfvars + .example), 마지막에 `Transformed N tfvars files`

- [ ] **Step 7.3: 잔여 검증**

Run:
```bash
grep -rE '^\s*(hub_subscription_id|spoke_subscription_id)\s*=' azure/ --include='terraform.tfvars*' || echo "OK: no subscription_id in tfvars"
grep -rE '^\s*backend_(resource_group_name|storage_account_name|container_name)\s*=' azure/ --include='terraform.tfvars*' || echo "OK: no legacy backend keys in tfvars"
```
Expected: 둘 다 `OK: ...`

- [ ] **Step 7.4: spoke placeholder 확인**

Run: `grep -r "<SPOKE_STATE_STORAGE_ACCOUNT>" azure/ --include='terraform.tfvars' | wc -l`
Expected: 0 이상 (spoke 참조 leaf 수만큼). placeholder가 실제로 박혔는지 확인.

- [ ] **Step 7.5: sample 확인**

Run: `cat azure/spoke/09.connectivity/peering/spoke-to-hub/terraform.tfvars`
Expected: subscription_id 라인 없음, hub_backend_* (hub state 참조) + spoke_backend_* (자기 state는 backend.hcl로 가지만 참조 변수만 있으면 됨 — 자기 state도 cross 참조는 아니므로) 값이 보임

- [ ] **Step 7.6: commit**

```bash
git add scripts/migrate/migrate-tfvars.py azure/
git commit -m "refactor(azure): tfvars에서 subscription_id 제거, hub/spoke backend 값 분리

subscription_id는 TF_VAR_* 환경변수로 이관. 기존 backend_* 라인 제거하고
data.tf 참조 대상에 따라 hub_backend_* (실 값) / spoke_backend_*
(<SPOKE_STATE_STORAGE_ACCOUNT> placeholder)를 추가. .example 상단에 환경변수
사용법 주석 추가.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 각 leaf에 backend.hcl.example 생성

**Files:**
- Create: `scripts/migrate/gen-backend-hcl-example.py`
- Create: 60개 leaf의 `backend.hcl.example`

각 leaf의 state key는 `azure/dev/<trunk>/<leaf-relative-path>/terraform.tfstate`로 결정된다. trunk가 hub면 hub storage 값, spoke면 spoke storage placeholder를 박는다.

- [ ] **Step 8.1: 생성 스크립트 작성**

Create `scripts/migrate/gen-backend-hcl-example.py`:

```python
#!/usr/bin/env python3
"""각 leaf에 backend.hcl.example 생성."""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MAPPING_FILE = REPO_ROOT / 'scripts' / 'migrate' / 'leaf-mapping.tsv'

TEMPLATES = {
    'hub': '''# backend.hcl.example — Hub leaf 전용
#
# 사용법:
#   1) 이 파일을 backend.hcl로 복사 (backend.hcl은 .gitignore 대상)
#   2) terraform init -backend-config=backend.hcl
#
# Hub 구독의 state storage에 저장됨.

resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstatea9911"
container_name       = "tfstate"
key                  = "azure/dev/hub/{leaf_path}/terraform.tfstate"
use_azuread_auth     = false
''',
    'spoke': '''# backend.hcl.example — Spoke leaf 전용
#
# 사용법:
#   1) 이 파일을 backend.hcl로 복사 (backend.hcl은 .gitignore 대상)
#   2) <PLACEHOLDER> 부분을 spoke 구독의 실제 값으로 교체
#   3) terraform init -backend-config=backend.hcl
#
# Spoke 구독의 state storage에 저장됨.

resource_group_name  = "<SPOKE_STATE_RG>"
storage_account_name = "<SPOKE_STATE_STORAGE_ACCOUNT>"
container_name       = "tfstate"
key                  = "azure/dev/spoke/{leaf_path}/terraform.tfstate"
use_azuread_auth     = false
''',
}

count = 0
with MAPPING_FILE.open() as f:
    for line in f:
        line = line.rstrip('\n')
        if not line:
            continue
        leaf_path, trunk = line.split('\t')
        leaf_dir = REPO_ROOT / 'azure' / trunk / leaf_path
        if not leaf_dir.is_dir():
            print(f'  SKIP (missing): {leaf_dir}')
            continue
        out = leaf_dir / 'backend.hcl.example'
        out.write_text(TEMPLATES[trunk].format(leaf_path=leaf_path))
        count += 1

print(f'\nGenerated {count} backend.hcl.example files')
```

- [ ] **Step 8.2: 실행**

Run: `python3 scripts/migrate/gen-backend-hcl-example.py`
Expected: `Generated 60 backend.hcl.example files`

- [ ] **Step 8.3: 카운트 검증**

Run:
```bash
find azure -name backend.hcl.example | wc -l
find azure/hub -name backend.hcl.example | wc -l
find azure/spoke -name backend.hcl.example | wc -l
```
Expected:
```
60
37
23
```

- [ ] **Step 8.4: sample 확인**

Run:
```bash
cat azure/hub/01.network/vnet/hub-vnet/backend.hcl.example
cat azure/spoke/04.apim/workload/backend.hcl.example
```
Expected: 각각 hub/spoke 템플릿대로, key 경로에 leaf path가 정확히 박혀있음

- [ ] **Step 8.5: commit**

```bash
git add scripts/migrate/gen-backend-hcl-example.py azure/
git commit -m "feat(azure): 각 leaf에 backend.hcl.example 생성

hub leaf는 hub state storage 값을 그대로, spoke leaf는 placeholder를 둠.
key 경로는 azure/dev/{trunk}/{leaf-relative-path}/terraform.tfstate.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 검증 (terraform validate + grep)

**Files:**
- Create: `scripts/migrate/verify.sh`

`terraform init -backend=false`는 모듈을 실제로 git clone하므로 GitLab 접근 권한이 필요하다. 본 task는 두 모드로 분기한다.

- [ ] **Step 9.1: 검증 스크립트 작성**

Create `scripts/migrate/verify.sh`:

```bash
#!/usr/bin/env bash
# hub/spoke 분리 작업 사후 검증
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "=== Grep 검증 ==="
echo "[1/5] kimchibee 잔여:"
grep -r "kimchibee" azure/ && echo "FAIL" || echo "OK"

echo "[2/5] legacy state key prefix (azure/dev/01.network 등 — hub/spoke 없는 형식):"
grep -rE 'key\s*=\s*"azure/dev/(0[0-9]|1[0-9])' azure/ --include='*.tf' && echo "FAIL" || echo "OK"

echo "[3/5] legacy backend_* 변수 참조 (data.tf):"
grep -rE '\bvar\.backend_(resource_group_name|storage_account_name|container_name)\b' azure/ --include='data.tf' && echo "FAIL" || echo "OK"

echo "[4/5] legacy backend_* 변수 선언 (variables.tf):"
grep -rE 'variable\s+"backend_(resource_group_name|storage_account_name|container_name)"' azure/ --include='variables.tf' && echo "FAIL" || echo "OK"

echo "[5/5] tfvars에 subscription_id:"
grep -rE '^\s*(hub|spoke)_subscription_id\s*=' azure/ --include='terraform.tfvars*' && echo "FAIL" || echo "OK"

echo
echo "=== Terraform validate (선택) ==="
echo "  GitLab 접근 권한이 있는 환경에서만 실행하세요. 명령:"
echo "    bash scripts/migrate/verify.sh --terraform"

if [[ "${1:-}" == "--terraform" ]]; then
  fails=0
  while IFS= read -r leaf_dir; do
    echo -n "  $leaf_dir ... "
    (cd "$leaf_dir" && terraform init -backend=false -no-color >/dev/null 2>&1 && terraform validate -no-color >/dev/null 2>&1) \
      && echo "PASS" \
      || { echo "FAIL"; fails=$((fails+1)); }
  done < <(find azure/hub azure/spoke -mindepth 2 -name main.tf -not -path "*/modules/*" -exec dirname {} \;)
  echo
  echo "Total failures: $fails"
fi
```

- [ ] **Step 9.2: grep 검증 실행**

Run:
```bash
chmod +x scripts/migrate/verify.sh
bash scripts/migrate/verify.sh
```
Expected: 5개 항목 모두 `OK`

- [ ] **Step 9.3: terraform validate 실행 (GitLab 접근 가능 환경에서만)**

Run: `bash scripts/migrate/verify.sh --terraform`
Expected: 모든 leaf에서 `PASS`, 마지막에 `Total failures: 0`

만약 GitLab 접근 권한이 없는 환경이면 이 step은 운영자가 별도 환경에서 수행. 본 작업 PR description에 "terraform validate는 GitLab 접근 가능 환경에서 별도 검증 예정" 명시.

- [ ] **Step 9.4: 실패 시 디버깅**

`Total failures: 0`이 아니면 각 실패 leaf의 `terraform init -backend=false` 출력을 보고 다음을 의심:

1. **모듈 인터페이스 불일치**: GitLab 통합 단일 버전과 호출부 변수가 안 맞음 → 호출부 main.tf 수정 (spec 9.4 후속 작업)
2. **GitLab 인증 실패**: SSH 키 또는 token 설정 누락 → 운영자에게 위임
3. **data.tf 누락**: variables.tf에 선언된 변수가 tfvars/backend.hcl 어디에도 없음 → 변환 스크립트 버그 → 해당 변환 스크립트 수정 후 재실행

- [ ] **Step 9.5: 검증 스크립트 commit**

```bash
git add scripts/migrate/verify.sh
git commit -m "chore(migrate): hub/spoke 분리 사후 검증 스크립트 추가

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 메모리 갱신 + 마무리

**Files:**
- Modify: `/Users/mzs02-andy/.claude/projects/-Users-mzs02-andy-Projects-mz-external-terraform-iac/memory/project_overview.md`
- Modify: `/Users/mzs02-andy/.claude/projects/-Users-mzs02-andy-Projects-mz-external-terraform-iac/memory/reference_repos.md`

본 작업으로 폴더 구조와 모듈 source 출처가 바뀌었으므로 메모리 갱신.

- [ ] **Step 10.1: project_overview.md 갱신**

다음 변경을 적용 (Edit tool 사용):
- "azure/ 하위에 스택이 직접 있음" → "azure/hub/, azure/spoke/ 두 트리로 분리, 각 트리 아래 9개 스택"
- 완료된 작업에 "5. hub/spoke 2-구독 분리 (커밋: <Task 3 커밋 해시>)" 추가
- 미완료/보류 사항에 "spoke 구독의 state storage account 생성 (운영자), TF_VAR_* 환경변수 주입 설정" 추가

- [ ] **Step 10.2: reference_repos.md 갱신**

다음 항목 추가:
- 내부 GitLab AVM 모듈 그룹: `https://dev-gitlab.kis.zone/platform-division/platform-engine/fortress/azure/azure/` — 모듈명 패턴 `terraform-azurerm-avm-<모듈>-main.git`

- [ ] **Step 10.3: PR 생성 (사용자 승인 시)**

작업 commit이 깨끗하게 분리되어 있으므로 PR 단위로:
- "refactor(azure): hub/spoke 2-구독 분리 마이그레이션"
- description: Task 1~9 요약 + spec 링크 + 검증 결과 (grep OK / terraform validate 운영자 수행 필요)

```bash
git push -u origin <feature-branch>
gh pr create --title "refactor(azure): hub/spoke 2-구독 분리 마이그레이션" --body "$(cat <<'EOF'
## Summary

- 60개 leaf를 azure/hub/ 와 azure/spoke/ 두 트리로 재배치
- state storage·backend 변수·subscription ID·AVM 모듈 source를 모두 hub/spoke 2-구독 운영에 맞게 변환
- 미커밋 변경(NSR 삭제 등)은 사전 정리 commit으로 별도 분리

자세한 설계: docs/superpowers/specs/2026-05-11-hub-spoke-subscription-split-design.md

## Test plan
- [x] grep 검증 통과 (scripts/migrate/verify.sh)
- [ ] terraform validate (GitLab 접근 가능 환경에서 운영자 수행)
- [ ] spoke 구독 state storage 생성 후 backend.hcl 채우고 init 시도

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review 결과

**Spec coverage 체크:**

| Spec 절 | Plan 대응 task |
|---|---|
| 3. 폴더 매핑 | Task 1 (매핑 작성), Task 3 (git mv) |
| 4. State 경계 | Task 5 (key 경로), Task 8 (backend.hcl.example) |
| 5.1. Subscription ID 환경변수 이관 | Task 7 (tfvars 정리) |
| 5.2. Backend 변수 2세트 | Task 6 (variables.tf), Task 7 (tfvars) |
| 5.3. data.tf 변환 규칙 | Task 5 |
| 6. 변환 절차 (12단계) | Task 1~9 |
| 8. 검증 기준 | Task 9 (verify.sh) |
| 9. 모듈 소스 마이그레이션 | Task 4 |

**전제 조건 (사용자에게 확인 필요):**
- Pre-flight: 미커밋 912 변경 처리 방식 결정
- Task 9.3: GitLab 접근 권한 보유 환경에서 terraform validate 실행

**Plan 한계:**
- 모듈 인터페이스 호환성(v0.7.1↔v0.17.1 단일화)은 운영자 사전 확인 기반. 만약 실제 validate에서 깨지면 후속 작업으로 호출부 수정 필요 (spec 9.4 명시됨).
- `keyvault-standalone` leaf는 spec 3절 매핑표에 없었으나 plan에서 hub로 추가 분류함 (data.tf가 hub_rg 참조).
