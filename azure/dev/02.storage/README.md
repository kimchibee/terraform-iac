# Storage (02) — 분류 폴더

Key Vault·모니터링 Storage·PE 등은 **`monitoring/` 리프**에서만 apply 합니다.

| 리프 | State 키 |
|------|-----------|
| `02.storage/monitoring` | `azure/dev/02.storage/monitoring/terraform.tfstate` |

상세는 [`monitoring/README.md`](monitoring/README.md) 를 참고하세요.

## Strict AVM Foundation 상태

- `02.storage/monitoring`은 현재 `terraform_modules/monitoring-storage`(hybrid) 의존이 있어 **Deferred** 입니다.
- strict AVM Foundation 파동에서는 신규 리프를 이 경로에 추가하지 않습니다.
- 후속 파동에서 `storage-account`, `key-vault`, `private-endpoint` AVM 모듈 조합으로 분해 전환합니다.
