# 07.identity — Entra ID(그룹 멤버십 등)

**리프에서만** `terraform plan` / `apply` 합니다. 상위 `group-membership`은 분류 폴더이며 apply 대상이 아닙니다.

## 리프

| 경로 | State 키 (예) |
|------|----------------|
| `group-membership/admin-core` | `azure/dev/07.identity/group-membership/admin-core/terraform.tfstate` |
| `group-membership/ai-developer-core` | `azure/dev/07.identity/group-membership/ai-developer-core/terraform.tfstate` |

`backend.hcl`은 프로젝트 루트에서 `./scripts/generate-backend-hcl.sh` 실행으로 생성합니다.

## 적용 순서 (넘버링: 07 → 08)

배포 순서는 **`07.identity` → `08.rbac`** 입니다. (멤버십을 먼저 맞춘 뒤 그룹 스코프 역할을 부여하는 흐름에 맞춤.)  
멤버십만 바꿀 때는 identity 리프만 plan/apply 하면 되고, `08.rbac`와는 독립적으로 실행할 수 있습니다.
