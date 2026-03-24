# 08.rbac — Azure RBAC (리프 배포)

기존 단일 `08.rbac` 스택을 **피드백 1**에 따라 리프별 독립 state로 나눴습니다. **각 하위 리프 디렉터리**에서만 `terraform plan` / `apply` 합니다.

## 리프와 역할

| 분류 | 리프 경로 | 내용 |
|------|-----------|------|
| **group** | `group/admin-hub-scope` | 관리자 그룹에 대한 Hub 범위 역할 |
| **group** | `group/ai-developer-spoke-scope` | AI 개발자 그룹 — Spoke RG·OpenAI 역할 |
| **principal** | `principal/hub-assignments` | 워크로드 MI(Monitoring VM 등) Hub 쪽 역할 |
| **principal** | `principal/spoke-assignments` | 동일 주체 Spoke 쪽 역할 |
| **authorization** | `authorization/hub-assignments` | `iam_role_assignments` 중 Hub provider |
| **authorization** | `authorization/spoke-assignments` | `iam_role_assignments` 중 Spoke provider |

State 키: `azure/dev/<위 경로>/terraform.tfstate`

## `iam_role_assignments` 마이그레이션

이전에는 **한** `terraform.tfvars`에 Hub/Spoke 항목이 섞여 있었습니다. 이제 **Hub 항목**(`use_spoke_provider = false`)은 `authorization/hub-assignments/terraform.tfvars`, **Spoke 항목**(`use_spoke_provider = true`)은 `authorization/spoke-assignments/terraform.tfvars`로 **나누어** 넣습니다.

## Backend

`./scripts/generate-backend-hcl.sh` 가 각 리프에 `backend.hcl`을 생성합니다.

## 권장 적용 순서 (선행 스택 이후)

1. `01.network` … `06.compute`, `04.apim`, `05.ai-services` 등 (remote state 참조)
2. `07.identity` 리프 (선택)
3. `08.rbac/group/*` → `08.rbac/principal/*` → `08.rbac/authorization/*` (의존 관계에 맞게)

`principal` 리프는 compute state에 Monitoring VM MI 출력이 있을 때 역할이 생성됩니다.
