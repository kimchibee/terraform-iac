# AI services (05) — 분류 폴더

Azure OpenAI·AI Foundry(ML Workspace)·Spoke Private Endpoint는 **`workload/` 리프**에서만 apply 합니다.

| 리프 | State 키 |
|------|-----------|
| `05.ai-services/workload` | `azure/dev/05.ai-services/workload/terraform.tfstate` |

상세는 [`workload/README.md`](workload/README.md) 를 참고하세요.

## 현재 상태

- `05.ai-services/workload`에서 OpenAI + AI Foundry Workspace + Spoke PE(OpenAI, AI Foundry) 생성을 관리합니다.
