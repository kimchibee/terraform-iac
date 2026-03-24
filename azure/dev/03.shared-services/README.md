# Shared services (03)

Shared services는 **리프 2개**로 나뉘며, 적용 순서는 `log-analytics` -> `shared` 입니다.

| 리프 | State 키 | 내용 |
|------|-----------|------|
| `03.shared-services/log-analytics` | `azure/dev/03.shared-services/log-analytics/terraform.tfstate` | Log Analytics Workspace |
| `03.shared-services/shared` | `azure/dev/03.shared-services/shared/terraform.tfstate` | Solutions, Action Group, Dashboard (LA state 참조) |

## 현재 원칙

- 두 리프 모두 **Git 공용 모듈**만 직접 참조합니다.
- 같은 디렉터리 아래의 `log-analytics-workspace/`, `shared-services/`는 **legacy local shim** 이며 신규 리프에서 참조하지 않습니다.
- `log-analytics`는 strict AVM Foundation의 in-scope leaf입니다.
- `shared`는 `terraform_modules/shared-services`가 non-AVM composite이므로 strict AVM Foundation에서는 Deferred입니다.

다른 스택(APIM, AI 등)은 **`shared` 리프 state만 참조**하면 Log Analytics와 shared 출력값을 함께 사용할 수 있습니다.
