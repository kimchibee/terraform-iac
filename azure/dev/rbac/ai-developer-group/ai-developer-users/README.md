# ai-developer-users — 멤버십 등록/변경/삭제

이 디렉터리는 **Terraform**으로 AI 개발자 그룹의 **멤버십**을 등록·변경·삭제합니다.

## 사용 방법

- **등록:** rbac 루트 `terraform.tfvars`의 `ai_developer_group_member_object_ids`에 추가할 멤버의 Azure AD **Object ID**를 추가한 뒤, rbac 루트에서 `terraform apply` 실행.
- **삭제:** 목록에서 해당 멤버 Object ID를 제거한 뒤 `terraform apply` 실행.
- **변경:** 목록을 수정한 뒤 `terraform apply`로 반영.

## Object ID 확인

Azure 포털 → Microsoft Entra ID → 사용자(또는 그룹) → 해당 리소스 → 개요 → **개체 ID**.

## 예시 (terraform.tfvars)

```hcl
ai_developer_group_member_object_ids = [
  "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
]
```
