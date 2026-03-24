# 아키텍처 기준 Terraform 동기화 가이드

이 문서는 이미 콘솔(수동)로 운영 중인 Azure 시스템을 현재 Terraform 코드와 일치시키고,
이후 신규 리소스는 Terraform으로만 배포하도록 전환하는 실행 가이드입니다.

핵심 목적:

- import 자체가 목적이 아니라, 운영 실환경과 코드 정합화가 목적
- 정합화 완료 후 신규/변경은 Terraform-only로 운영

---

## 1) 적용 범위와 원칙

- 대상: Hub/Spoke 아키텍처의 `01.network` ~ `09.connectivity` 전체 스택
- 원칙 1: 운영 핵심 리소스(VNet, APIM, OpenAI, ML Workspace, Key Vault, Storage)는 이름 유지 우선
- 원칙 2: 코드/변수/출력 구조를 실환경에 먼저 맞춘 뒤 state 동기화
- 원칙 3: 전환 완료 후 콘솔 수동 변경 금지

---

## 2) Phase A - 현재 배포 리소스 전체 인벤토리 수집

목표: Azure에 실제로 배포된 리소스를 먼저 확정합니다.

### A-1. 구독 컨텍스트 확인

```bash
az login
az account list --query "[].{name:name,id:id,tenant:tenantId}" -o table
```

### A-2. 구독별 리소스 전체 수집 (Hub / Spoke)

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
az resource list -o json > hub_resources.json

az account set --subscription "<SPOKE_SUBSCRIPTION_ID>"
az resource list -o json > spoke_resources.json
```

### A-3. 타입별 집계 (선택)

```bash
az graph query -q "Resources | summarize count() by type | order by type asc"
```

---

## 3) Phase B - 코드와 실환경 비교, 수정 항목 리스트업

목표: import 전에 코드가 실환경을 표현하도록 맞춥니다.

### B-1. 비교 기준

- 이름 규칙(`project_name`, 접두/접미, 리소스명)
- SKU/성능/보안 설정
- 네트워크 구조(서브넷, PE, NSG/ASG, route)
- remote state output key 정합
- enable 플래그/조건(`count`, `for_each`)

### B-2. 수정 항목 리스트(필수 산출물)

| 스택/리프 | 실환경 값 | 현재 코드 값 | 조치 |
|---|---|---|---|
| `05.ai-services/workload` | ML Workspace 이름 A | 코드 이름 B | 변수/locals 수정 |
| `08.rbac/group/*` | 그룹 Object ID 존재 | tfvars 비어 있음 | tfvars 운영값 반영 |

### B-3. 코드 수정 우선순위

1. `variables.tf`, `terraform.tfvars`
2. `main.tf` (조건식, 모듈 인자, 참조 경로)
3. `outputs.tf`
4. README/운영 문서

---

## 4) Phase C - 상태(state) 동기화

목표: 코드와 실환경이 맞는 상태에서 state를 구성합니다.

### C-1. 리프별 기본 절차

```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
```

- `already exists`가 발생하면 해당 리소스는 `terraform import`로 state 편입
- 단, import 전에 코드/변수가 실환경과 일치하는지 먼저 확인

### C-2. import 적용 기준

- 적용: 실환경에서 유지할 리소스
- 제외: Terraform 관리 대상이 아닌 리소스

---

## 5) Phase D - 스택별 싱크 판정 (init/plan 출력 기준)

요청 기준대로 각 리프 `init + plan` 출력으로 싱크를 판정합니다.

### 판정 규칙

- `SYNC`: `No changes` 또는 의도한 소량 변경만 존재
- `PARTIAL`: 일부 리프 drift 존재
- `NOT SYNC`: 대량 create/destroy/replace 또는 참조 오류

### 출력 기반 체크 포인트

- `Unsupported attribute` 없음
- `Resource already exists` 없음
- 운영 핵심 리소스에서 대규모 `replace` 없음
- RBAC/Identity `count=0`가 의도값인지 확인

---

## 6) 권장 실행 순서 (의존성 기준)

1. `01.network`
2. `02.storage`
3. `03.shared-services`
4. `04.apim`
5. `05.ai-services`
6. `06.compute`
7. `07.identity`
8. `08.rbac`
9. `09.connectivity`

---

## 7) 동기화 완료 정의

아래를 모두 만족하면 동기화 완료로 판단합니다.

- 모든 리프 `terraform init` 성공
- 모든 리프 `terraform plan`이 `SYNC`
- 핵심 리소스(VNet/Storage/APIM/OpenAI/ML/VM/Peering) 코드-실환경 일치
- RBAC/Identity 운영값 반영 완료
- 이후 신규 생성은 Terraform 경로로만 수행

---

## 8) Terraform-only 운영 전환 규칙

- 신규 리소스: Terraform 코드 변경 -> plan -> apply
- 콘솔 수동 변경 금지 (예외 시 즉시 코드/state 반영)
- 정기적으로 리프별 `plan` 실행해 drift 점검

---

## 9) AI 작업 지시 프롬프트 템플릿

아래 템플릿을 AI에게 그대로 전달하면 동기화 작업을 안정적으로 수행할 수 있습니다.

### 9-1. 전체 동기화 시작 프롬프트

```text
목표:
이미 콘솔로 운영 중인 Azure Hub/Spoke 환경을 현재 terraform-iac 코드와 먼저 일치시키고,
동기화 완료 후 신규 리소스는 Terraform으로만 배포하도록 전환한다.

작업 순서:
1) Hub/Spoke 구독 전체 리소스를 az 명령으로 수집해 인벤토리 작성
2) 각 스택(01~09) 코드와 실환경 비교 후 수정 항목 리스트 작성
3) 코드(variables/tfvars/main/outputs) 정합화 먼저 수행
4) 필요한 리소스만 terraform import로 state 편입
5) 각 리프에서 init/plan 실행 후 SYNC/PARTIAL/NOT SYNC 판정표 작성

제약:
- terraform-modules 레포 코드는 수정 금지(필요 시 사전 승인)
- 운영 핵심 리소스는 이름 유지 우선, 불필요한 replace 금지
- 변경 이유와 영향도를 각 수정 항목에 명시

결과물:
- 스택별 수정 항목 리스트
- 반영된 코드 변경
- 리프별 plan 결과와 최종 싱크 판정표
```

### 9-2. 스택 단위 실행 프롬프트

```text
대상 스택: 08.rbac

요청:
1) 현재 Azure 실환경과 08.rbac 코드/tfvars를 비교
2) count/for_each 조건으로 인해 미배포되는 리소스가 있는지 확인
3) 필요한 tfvars 운영값(Object ID, scope, iam_role_assignments) 제안
4) init/plan 결과 기준으로 싱크 여부를 판정

출력 형식:
- 원인 요약(왜 미배포인지)
- 수정 파일 목록
- 변경 전/후 기대 plan 결과
```

### 9-3. 검증 전용 프롬프트

```text
코드 수정은 하지 말고 검증만 수행:
1) 각 리프 terraform init/plan 실행
2) 결과를 SYNC/PARTIAL/NOT SYNC로 분류
3) NOT SYNC 항목은 원인(변수 누락, output mismatch, import 필요 등)과 해결 단계 제시
```

### 9-4. 안전장치 문구(프롬프트에 항상 포함 권장)

```text
중요:
- destructive 명령은 사전 승인 없이 실행하지 않는다.
- 예기치 않은 파일 변경이 감지되면 즉시 중단하고 보고한다.
- 변경은 항상 스택 의존성 순서(01->09) 기준으로 수행한다.
```

---

## 10) AI 없이 수동으로 진행하는 복사-붙여넣기 런북 (Bash)

아래는 AI 없이도 운영자가 그대로 실행할 수 있는 최소 절차입니다.

### 10-1. 세션 초기화 및 변수 선언

```bash
# repo 루트로 이동
cd "/c/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac"

# 환경 변수(본인 환경 값으로 변경)
export HUB_SUBSCRIPTION_ID="<hub-subscription-id>"
export SPOKE_SUBSCRIPTION_ID="<spoke-subscription-id>"
export BACKEND_RG="terraform-state-rg"
export BACKEND_SA="tfstate7dc60879"
export BACKEND_CONTAINER="tfstate"
```

### 10-2. 현재 운영 리소스 인벤토리 수집

```bash
mkdir -p sync-artifacts

az login
az account set --subscription "$HUB_SUBSCRIPTION_ID"
az resource list -o json > sync-artifacts/hub_resources.json

az account set --subscription "$SPOKE_SUBSCRIPTION_ID"
az resource list -o json > sync-artifacts/spoke_resources.json

az graph query -q "Resources | summarize count() by type | order by type asc" -o table > sync-artifacts/resource_type_summary.txt
```

### 10-3. 백엔드 파일 생성/검증

```bash
# 스크립트가 있으면 실행
if [ -f "./scripts/generate-backend-hcl.sh" ]; then
  chmod +x ./scripts/generate-backend-hcl.sh
  ./scripts/generate-backend-hcl.sh
fi

# 누락된 backend.hcl 확인
find ./azure/dev -type f -name "main.tf" | while read -r f; do
  d="$(dirname "$f")"
  if [ ! -f "$d/backend.hcl" ]; then
    echo "[MISSING backend.hcl] $d"
  fi
done
```

### 10-4. 스택 순서대로 init/plan 실행 및 로그 수집

```bash
mkdir -p sync-artifacts/plan-logs

# 의존성 순서(리프는 디렉터리 탐색으로 수집)
for stack in 01.network 02.storage 03.shared-services 04.apim 05.ai-services 06.compute 07.identity 08.rbac 09.connectivity; do
  echo "===== STACK: $stack ====="
  find "./azure/dev/$stack" -type f -name "main.tf" | while read -r tf; do
    leaf="$(dirname "$tf")"
    [ -f "$leaf/backend.hcl" ] || continue

    echo "---- LEAF: $leaf ----"
    (
      cd "$leaf" || exit 1
      terraform init -backend-config=backend.hcl -input=false
      if [ -f terraform.tfvars ]; then
        terraform plan -var-file=terraform.tfvars -input=false -no-color > "../../../sync-artifacts/plan-logs/$(echo "$leaf" | tr '/\\' '__').plan.txt" 2>&1
      else
        terraform plan -input=false -no-color > "../../../sync-artifacts/plan-logs/$(echo "$leaf" | tr '/\\' '__').plan.txt" 2>&1
      fi
    )
  done
done
```

### 10-5. plan 결과 자동 분류 (SYNC / PARTIAL / NOT_SYNC)

```bash
mkdir -p sync-artifacts/reports
REPORT="sync-artifacts/reports/sync_status.tsv"
echo -e "leaf\tstatus\treason" > "$REPORT"

for p in sync-artifacts/plan-logs/*.plan.txt; do
  leaf="$(basename "$p" .plan.txt)"
  if rg -q "No changes\\.|0 to add, 0 to change, 0 to destroy" "$p"; then
    echo -e "$leaf\tSYNC\tno drift" >> "$REPORT"
  elif rg -q "Unsupported attribute|Error:|Resource already exists|Invalid index|Attribute redefined" "$p"; then
    echo -e "$leaf\tNOT_SYNC\tplan error or reference mismatch" >> "$REPORT"
  else
    echo -e "$leaf\tPARTIAL\tdrift exists (review manually)" >> "$REPORT"
  fi
done

column -t -s $'\t' "$REPORT"
```

### 10-6. 코드 정합화 후 import 수행 (필요 리소스만)

```bash
# 예시: 특정 리프에서 리소스 import
cd "/c/Users/nonoc/OneDrive/바탕 화면/challenge/terraform-iac/azure/dev/05.ai-services/workload"
terraform init -backend-config=backend.hcl -input=false

# 주소/ID는 실제 plan 오류 메시지 기준으로 교체
terraform import 'azurerm_machine_learning_workspace.this' '/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.MachineLearningServices/workspaces/<name>'
```

중요:

- import 전에 `main.tf`/`tfvars`가 실환경을 정확히 표현하도록 먼저 수정
- 유지 대상 리소스만 import
- 제외 대상은 코드에서 비활성화 또는 관리 경계 문서화

### 10-7. 최종 싱크 재검증

```bash
# 동일 루프 재실행 후 리포트 재생성
# 목표: NOT_SYNC 0건, PARTIAL 최소화
```

### 10-8. 전환 완료 체크리스트

- 모든 리프 `terraform init` 성공
- 주요 리프 `plan`이 SYNC
- 운영 핵심 리소스에서 의도치 않은 replace 없음
- 이후 신규 리소스는 Terraform 코드 변경으로만 생성
