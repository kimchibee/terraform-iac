# Azure Import 작업 — Quickstart

`az login` 없이 **Service Principal 환경변수**만으로 Terraform/az CLI 인증 후 Azure 리소스를 Terraform state로 import 하는 절차.

상세 spec: `docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md`
상세 plan: `docs/superpowers/plans/2026-05-12-azure-import-and-verify-plan.md`

---

## 1. 사전 조건

- Terraform v1.5+ (검증: v1.14.6)
- Azure CLI (`az`) 설치, `jq` 설치
- Service Principal 자격증명 (Contributor + Storage Blob Data Contributor + Directory.Read.All)
- 인터넷 접근 (terraform-modules git source 다운로드)
- **state backend storage account 존재** — 없으면 `azure/00.state-backend/` 부트스트랩 스택을 먼저 실행 (해당 README 참조)

---

## 2. 다른 PC 로 옮길 파일

레포 전체 `git clone` 이 가장 깔끔하지만, **순수 import 작업물만** 추리면:

```
.gitignore                                                          # docs/import 추적 허용 패치 포함
docs/import/leaf-to-resource-map.csv                                # seeded (header + 61 빈 행)
docs/superpowers/specs/2026-05-12-azure-import-and-verify-design.md
docs/superpowers/plans/2026-05-12-azure-import-and-verify-plan.md
scripts/import/README.md                    # 이 파일
scripts/import/env.sh                       # SP 환경변수 지원
scripts/import/az-sp-login.sh               # SP 인증 헬퍼
scripts/import/az-inventory.sh
scripts/import/leaf-list.sh
scripts/import/tf-backend-key.sh
scripts/import/tf-init-leaf.sh
scripts/import/tf-plan-leaf.sh
scripts/import/generate-imports.sh
scripts/import/run-import.sh
scripts/import/run-all-stacks.sh
```

추가로 **반드시 함께 필요한 코드**:
- `azure/` 전체 트리 (Hub/Spoke 9 스택 ~61 leaf)
- `modules/` 또는 git source 모듈 다운로드를 위한 인터넷 접근

---

## 3. 작업 시퀀스 (az login 없이)

```bash
# 0) (최초 1회) state backend 가 없으면 부트스트랩
#    - 분리 SA (표준): cd azure/hub/00.state-backend && terraform init && terraform apply
#                      cd azure/spoke/00.state-backend && terraform init && terraform apply
#    - 단일 SA: hub 스택만 실행 + storage_account_name 을 공통명으로 override
#    상세: azure/hub/00.state-backend/README.md ("단일 SA 모드로 사용하는 법" 절)

# 1) 레포 clone (또는 파일 복사)
git clone git@github.com:kimchibee/terraform-iac.git
cd terraform-iac
git log --oneline | head -10   # f2bafc7 까지 있는지 확인

# 2) GitLab CI Variables 와 동일한 값을 로컬 셸에 export
export ARM_CLIENT_ID="<sp-app-id>"
export ARM_CLIENT_SECRET="<sp-secret>"
export ARM_TENANT_ID="<tenant-guid>"
export ARM_SUBSCRIPTION_ID="<sub-guid>"          # 또는 ↓ 둘 중 하나
export HUB_SUBSCRIPTION_ID="<hub-sub-guid>"
export SPOKE_SUBSCRIPTION_ID="<spoke-sub-guid>"

# 3) 공통 env 로드 + az CLI SP 로그인
source scripts/import/env.sh
./scripts/import/az-sp-login.sh
# → "Subscription | TenantId" 표 출력되면 OK

# 4) state SA 접근 확인 (plan Task 0.1 Step 5)
#    cross-tenant(Lighthouse 등) 시 --auth-mode login 이 "issuer did not match" 401 을
#    낼 수 있음 → 권장은 account-key 방식 (아래 4-A). 토큰 issuer 오류가 보이면 4-B 실행.

# 4-A) 권장: control-plane 으로 storage 존재 확인 + account-key 로 data-plane 확인
export ARM_ACCESS_KEY="$(az storage account keys list \
  --resource-group "$TF_BACKEND_RG" \
  --account-name "$TF_BACKEND_SA" \
  --query '[0].value' -o tsv)"

az storage container show \
  --name "$TF_BACKEND_CONTAINER" \
  --account-name "$TF_BACKEND_SA" \
  --account-key "$ARM_ACCESS_KEY" \
  --query '{name:name}' -o table

# 4-B) "issuer did not match" 401 발생 시 원인 진단
./scripts/import/diagnose-storage-auth.sh
# → token tid vs storage subscription tenant 비교, 가설 자동 판정

# 5) 인벤토리 추출 (plan Task 0.2 Step 2)
./scripts/import/az-inventory.sh

# 6) plan Task 0.3 부터 순서대로 진행 (leaf 매핑 → pilot → 스택대표 → 일괄)
```

---

## 4. 인증 동작 정리

| 도구 | 인증 방식 | 별도 단계 |
|---|---|---|
| Terraform `azurerm` provider | `ARM_CLIENT_ID/SECRET/TENANT_ID/SUBSCRIPTION_ID` 자동 인식 | 없음 — env에 export만 |
| Terraform `azurerm` backend (state SA) | 동일 | 없음 |
| az CLI (`az resource list`, `az group show` 등) | SP 로그인 필요 | `./scripts/import/az-sp-login.sh` 1회 |
| `terraform_remote_state` data source | 동일 ARM_* | 없음 |

**Interactive `az login` 필요 없음**. SP 인증 1회 후 토큰 만료까지 유효 (기본 1시간 — 만료 시 az-sp-login.sh 재실행).

---

## 5. 스크립트 레퍼런스

| 스크립트 | 역할 | 사용 시점 |
|---|---|---|
| `env.sh` | 공통 환경변수 export (subscription, backend SA, REPO_ROOT 등). SP 변수 우선 인식 | 작업 시작 시 `source` |
| `az-sp-login.sh` | ARM_* env vars 로 az CLI SP 인증 | env.sh source 직후 1회 |
| `diagnose-storage-auth.sh` | storage data-plane AAD 인증 오류("issuer did not match" 등) 진단. 토큰 tid vs storage subscription tenant 비교 후 자동 판정 | 401/issuer 오류 발생 시 |
| `az-inventory.sh` | `az resource list` → `docs/import/inventory.json` + `inventory.csv` | Phase 0 인벤토리 추출 |
| `leaf-list.sh` | azure/ 하위 모든 leaf (main.tf 디렉토리) 나열 | 매핑 CSV 초안 작성 시 |
| `tf-backend-key.sh` | leaf 경로 → state backend key 변환 (`azure/dev/<...>/terraform.tfstate`) | 다른 스크립트가 호출 |
| `tf-init-leaf.sh <leaf>` | 단일 leaf에 `-backend-config` 주입하여 `terraform init` | leaf 작업 시작 시 |
| `tf-plan-leaf.sh <leaf>` | 단일 leaf `terraform plan -out=plan.out` 후 요약 추출 | 수동 plan 확인 시 |
| `generate-imports.sh` | `leaf-to-resource-map.csv` 채워진 행마다 `leaf/imports.tf` 생성 | Phase 3 진입 직전 |
| `run-import.sh <leaf>` | 단일 leaf init → plan → apply → imports.tf 제거 → sanity. run-log.csv 기록 | leaf 1개 import 시 |
| `run-all-stacks.sh` | 의존 순서대로 모든 leaf 에 run-import.sh 실행 | 전체 일괄 import 시 |

---

## 6. 주의사항

- **SP RBAC**: Contributor (target 구독), Storage Blob Data Contributor (state SA `tfstatea9911`), Azure AD 관련 leaf(07.identity) 작업 시 `Directory.Read.All` 등 Graph 권한 추가 필요
- **구독 변수 우선순위**: `ARM_SUBSCRIPTION_ID`가 있으면 `HUB_SUBSCRIPTION_ID`보다 우선. `HUB_SUBSCRIPTION_ID` 기반으로 통일하려면 `unset ARM_SUBSCRIPTION_ID` 후 `source scripts/import/env.sh`
- **state 충돌 방지**: 다른 작업자가 동시에 같은 leaf 를 import 하지 않도록 사전 조율
- **imports.tf 잔재**: `run-import.sh` 가 apply 후 자동 제거하지만, 중단된 작업이 있으면 `find azure -name imports.tf` 로 확인
- **plan.out 잔재**: `.gitignore` 에 `tfplan`/`*.tfplan` 만 있고 `plan.out` 은 없음. 수동 정리 또는 추후 gitignore 보강
