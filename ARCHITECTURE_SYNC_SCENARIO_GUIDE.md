# 아키텍처 기준 Terraform 동기화 시나리오 가이드

이 문서는 Azure에 이미 리소스가 배포되어 있고, 현재 리포지토리의 Terraform 코드와 **동기화(import/상태 정리)** 해야 하는 상황을 가정한 운영 가이드입니다.

전제:

- 대상 아키텍처는 Hub/Spoke 구조이며, 네트워크/스토리지/APIM/AI/컴퓨트/권한/연결 스택이 모두 존재
- 배포된 리소스가 코드보다 먼저 존재할 수 있음
- 목표는 `terraform apply` 시 불필요한 재생성 없이, 코드와 실제 리소스 상태를 일치시키는 것

---

## 1) 사전 점검 (반드시 먼저)

1. 구독/테넌트 확인
   - `az login`
   - `az account show -o table`
2. backend 저장소 확인
   - `bootstrap/backend/terraform.tfvars` 값과 실제 Storage Account/Container 일치 확인
3. Provider 등록 확인
   - 최소: `Microsoft.Network`, `Microsoft.Storage`, `Microsoft.KeyVault`, `Microsoft.Insights`, `Microsoft.OperationalInsights`, `Microsoft.ApiManagement`, `Microsoft.CognitiveServices`, `Microsoft.MachineLearningServices`
4. 리프별 `backend.hcl` 생성
   - 루트에서 `scripts/generate-backend-hcl.sh` 실행 또는 수동 생성
5. 리소스 네이밍 룰 확정
   - `project_name`, `environment`, 접두/접미 규칙을 먼저 잠금

---

## 2) 네이밍 룰 불일치 정리 전략

이미 배포된 리소스 이름이 코드 규칙과 다를 때는 아래 순서로 판단합니다.

1. **서비스 영향 큰 리소스** (VNet, APIM, OpenAI, ML Workspace, Key Vault, Storage)
   - 가급적 이름 변경하지 않고 Terraform 코드(변수/locals)를 실제 이름에 맞춰 동기화
2. **재생성 허용 리소스** (일부 진단 설정, 보조 구성)
   - 네이밍 룰 우선으로 코드 정리 후 재생성 허용 가능
3. **전역 유니크 이름 리소스** (Storage, Key Vault)
   - suffix 전략 사용(예: `random_string`)으로 충돌/soft-delete 이슈 회피

권장 원칙:

- 운영 리소스는 이름 유지 + state import
- 신규 생성 리소스만 표준 네이밍 적용

---

## 3) 리프별 상태 파일 생성/동기화 절차

아래를 각 리프 디렉토리에서 반복합니다.

1. 초기화
   - `terraform init -backend-config=backend.hcl`
2. 드리프트/충돌 확인
   - `terraform plan -var-file=terraform.tfvars`
3. 이미 존재 리소스가 있으면 import
   - 오류 메시지의 리소스 주소와 Azure Resource ID를 사용해 `terraform import`
4. 재검증
   - `terraform plan -var-file=terraform.tfvars`
5. 변경 승인
   - `terraform apply -var-file=terraform.tfvars`

핵심:

- `Resource already exists`는 삭제가 아니라 **import로 해결**
- import 이후 plan이 0~최소 변경인지 확인

---

## 4) 현재 아키텍처 기준 권장 동기화 순서

1. `01.network`
2. `02.storage`
3. `03.shared-services`
4. `04.apim`
5. `05.ai-services`
6. `06.compute`
7. `07.identity`
8. `08.rbac`
9. `09.connectivity`

이유:

- 상위 네트워크/스토리지 상태를 하위 스택이 remote state로 참조함
- 순서를 어기면 output 누락/Unsupported attribute가 발생하기 쉬움

---

## 5) 자주 발생하는 동기화 이슈와 대응

1. `MissingSubscriptionRegistration`
   - 원인: 구독 Provider 미등록
   - 대응: `az provider register --namespace <RP>`
2. `Resource already exists`
   - 원인: 리소스 선배포, state 미등록
   - 대응: `terraform import`
3. `Soft-deleted resource exists` (ML Workspace/Key Vault 등)
   - 원인: 동일 이름 soft-delete 잔존
   - 대응: purge 또는 suffix 기반 이름 재설계
4. `Unsupported attribute` (remote state output 키 불일치)
   - 원인: 참조 경로/출력명 변경
   - 대응: upstream leaf output 정합성 확인 후 참조 코드 수정

---

## 6) 신규 리소스 추가 / 스펙 변경 시 체크리스트

### A. 신규 리소스 추가

1. 해당 리프의 `variables.tf`에 입력 변수 추가
2. `terraform.tfvars`/`terraform.tfvars.example`에 운영값/예시 추가
3. `main.tf`에 리소스 또는 모듈 블록 추가
4. `outputs.tf`에 후속 스택 참조용 출력 추가
5. `README.md`에 변경 포인트 기록
6. `plan -> apply` 후 downstream 리프 plan 재확인

### B. 네임/스펙 변경

1. 변경 대상이 ForceNew인지 먼저 확인(plan에서 replace 여부 확인)
2. 운영 영향이 큰 리소스는 가능한 한 이름 고정, 스펙만 조정
3. replace가 불가피하면 점검 시간대/롤백 경로 먼저 확정
4. 적용 후 `09.connectivity`와 진단 설정까지 재검증

---

## 7) 검증 기준 (동기화 완료 정의)

아래를 만족하면 동기화 완료로 판단합니다.

- 각 리프 `terraform plan` 결과가 무변경 또는 의도한 변경만 포함
- NSG/ASG/Subnet Association이 아키텍처 의도와 일치
- Hub/Spoke Peering이 양방향 `Connected`
- AI/APIM/Storage/Key Vault의 Private Endpoint가 기대 개수대로 존재
- 주요 출력값(remote state 소비 값)이 후속 스택 plan에서 정상 해석됨

---

## 8) 운영 권장사항

- 리소스 수동 생성보다 Terraform 경유 생성 우선
- 예외적으로 수동 생성 시 즉시 import하여 state 동기화
- 리프 단위로 작게 plan/apply하고, 대규모 일괄 변경은 지양
- 커밋 메시지는 "왜 이 동기화가 필요했는지" 중심으로 기록
