# Shared services (03)

Shared services는 **리프 2개**로 나뉘며, 적용 순서는 `log-analytics` -> `shared` 입니다.

| 리프 | State 키 | 내용 |
|------|-----------|------|
| `03.shared-services/log-analytics` | `azure/dev/03.shared-services/log-analytics/terraform.tfstate` | Log Analytics Workspace |
| `03.shared-services/shared` | `azure/dev/03.shared-services/shared/terraform.tfstate` | Solutions, Action Group, Dashboard (LA state 참조) |

## 현재 원칙

- 두 리프 모두 **Git 공용 모듈**만 직접 참조합니다.
- `log-analytics`와 `shared` 리프를 순차로 적용합니다.
- 다른 스택은 `shared` 리프 state output을 참조합니다.

다른 스택(APIM, AI 등)은 **`shared` 리프 state만 참조**하면 Log Analytics와 shared 출력값을 함께 사용할 수 있습니다.

## 현재 상태

- `03.shared-services/log-analytics` 배포 완료
- `03.shared-services/shared` 배포 완료
