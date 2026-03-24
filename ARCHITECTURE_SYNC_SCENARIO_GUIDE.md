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
