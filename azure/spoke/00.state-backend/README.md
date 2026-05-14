# azure/spoke/00.state-backend — Spoke 측 state backend 부트스트랩

Spoke 구독에 Spoke leaf 들의 Terraform state 를 저장할 Storage Account 를 생성하는
**1회용 bootstrap 스택**. `backend.tf` 가 없어 자기 자신의 state 는 로컬
(`./terraform.tfstate`) 에 보관.

## 언제 실행하나

- **hub/spoke 구독 분리 시나리오**에서 spoke 측 state SA 가 없을 때
- 새 PC / 새 환경에서 처음 셋업할 때
- 이미 운영 SA(`tfstatea9911` 통합 SA 등)가 존재하면 실행 불요

## 단일 SA 모드 vs 분리 SA 모드

상세 비교는 `azure/hub/00.state-backend/README.md` 의 "단일 SA 모드 vs 분리 SA 모드"
절 참조. 두 스택은 분리 모드일 때 한 쌍으로 운용된다.

단일 SA 모드라면 이 스택은 실행 불요 — hub 측 스택에서 SA 이름을 공통명으로 override
하고, 이 spoke 측 leaf 들의 `spoke_backend_*` 도 같은 SA 를 가리키도록 셋하면 된다.

## 실행 절차

```bash
cd <repo-root>
source scripts/import/env.sh

# Spoke 구독으로 SP 로그인 (env.sh 의 SPOKE_SUBSCRIPTION_ID 가 셋되어 있어야 함)
export ARM_SUBSCRIPTION_ID="$SPOKE_SUBSCRIPTION_ID"
./scripts/import/az-sp-login.sh

cd azure/spoke/00.state-backend
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars               # spoke_subscription_id 입력

terraform init                         # backend.tf 없음 → local state
terraform plan                         # Plan: 3 to add
terraform apply -auto-approve

terraform output                       # RG/SA/Container 이름 출력
```

출력된 이름들을 모든 Spoke leaf 의 `terraform.tfvars` 에 다음 변수로 셋:

```hcl
spoke_backend_resource_group_name  = "terraform-state-spoke-rg"
spoke_backend_storage_account_name = "tfstatespka9911"
spoke_backend_container_name       = "tfstate"
```

## 산출

| 리소스 | 기본 이름 | 비고 |
|---|---|---|
| Resource Group | `terraform-state-spoke-rg` | Spoke 구독 내 |
| Storage Account | `tfstatespka9911` | 글로벌 unique. 충돌 시 tfvars 에서 변경 |
| Blob Container | `tfstate` | private, AAD/key 둘 다 허용 |

추가 보호:
- `versioning_enabled = true`
- `min_tls_version = TLS1_2`
- `allow_nested_items_to_be_public = false`
- Tag: `Side = spoke`

## state 파일 관리

이 스택은 자기 자신의 state 를 **로컬**(`./terraform.tfstate`) 에 보관.

- `*.tfstate` 가 .gitignore 대상이라 git 추적 안 됨
- 분실 시 변경 적용 전에 `terraform import` 로 3 리소스 재등록 필요
- 권장: 안전한 저장소에 백업

## 더 안전한 대안 — Self-hosted migration

```bash
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-spoke-rg"
    storage_account_name = "tfstatespka9911"
    container_name       = "tfstate"
    key                  = "azure/dev/spoke/00.state-backend/terraform.tfstate"
  }
}
EOF

terraform init -migrate-state
```

## 삭제 시 주의

`terraform destroy` 하면 모든 Spoke leaf 의 state 가 사라진다. **운영에서는 절대 금지.**
