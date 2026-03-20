# admin-users — 멤버십 등록/변경/삭제

이 디렉터리는 **Terraform**으로 관리자 그룹의 **멤버십**을 등록·변경·삭제합니다.  
**plan/apply는 rbac 스택 루트(`azure/dev/07.rbac`)에서만** 실행합니다.

## 디렉터리·파일 역할

| 파일 | 역할 |
|------|------|
| `main.tf` | `azuread_group_member`: `member_object_ids`에 있는 Object ID만 그룹 멤버로 유지 |
| `variables.tf` | `group_object_id`, `member_object_ids` 선언(값은 상위 `admin-group` 모듈·루트에서 전달) |
| `versions.tf` | `azuread` provider 버전 |

## 사용 방법

- **등록:** rbac 루트 `terraform.tfvars`의 `admin_group_member_object_ids`에 추가할 멤버의 Azure AD **Object ID**를 추가한 뒤, rbac 루트에서 `terraform apply` 실행.
- **삭제:** `admin_group_member_object_ids` 목록에서 해당 멤버 Object ID를 제거한 뒤 `terraform apply` 실행. 해당 멤버가 그룹에서 제거됩니다.
- **변경:** 목록을 수정한 뒤 `terraform apply`로 반영.

## Object ID 확인

- **사용자:** Azure 포털 → Microsoft Entra ID → 사용자 → 해당 사용자 → 개요 → **개체 ID**
- **그룹/서비스 주체:** 동일하게 해당 리소스 개요에서 **개체 ID** 복사.

## 예시 (terraform.tfvars)

```hcl
admin_group_member_object_ids = [
  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",  # 사용자 또는 그룹 Object ID
  "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
]
```
