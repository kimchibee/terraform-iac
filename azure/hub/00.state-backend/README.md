# azure/hub/00.state-backend — Hub 측 state backend 부트스트랩

Hub 구독에 Hub leaf 들의 Terraform state 를 저장할 Storage Account 를 생성하는
**1회용 bootstrap 스택**. `backend.tf` 가 없어 자기 자신의 state 는 로컬
(`./terraform.tfstate`) 에 보관.

## 언제 실행하나

- **hub/spoke 구독 분리 시나리오**에서 hub 측 state SA 가 없을 때
- 새 PC / 새 환경에서 처음 셋업할 때
- 이미 운영 SA(`tfstatea9911` 통합 SA 등)가 존재하면 실행 불요

## 단일 SA 모드 vs 분리 SA 모드

| 모드 | 사용 스택 | 비고 |
|---|---|---|
| **분리 SA** (이 스택 + `azure/spoke/00.state-backend/`) | hub 따로, spoke 따로 | hub/spoke 구독 분리 시나리오 표준. 권한/blast-radius 격리 |
| **단일 SA** (이 스택만 사용, 이름 override) | hub 만 실행하고 SA 이름을 운영 공통명으로 변경 | 단일 구독, 단순 운영. hub/spoke leaf 가 모두 같은 SA 가리킴 |

### 단일 SA 모드로 사용하는 법

이 스택만 실행하고 `terraform.tfvars` 에서 SA 이름을 운영 공통명으로 override:

```hcl
# azure/hub/00.state-backend/terraform.tfvars
hub_subscription_id  = "20e3a0f3-f1af-4cc5-8092-dc9b276a9911"
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstatea9911"             # ← 공통 SA 이름
tags = {
  ManagedBy = "Terraform"
  Purpose   = "tfstate"
  # Side 태그 생략 또는 "shared" 로
}
```

그리고 모든 hub/spoke leaf 의 `terraform.tfvars` 에서 backend 이름을 같은 값으로 셋:

```hcl
# hub leaf 들
hub_backend_resource_group_name  = "terraform-state-rg"
hub_backend_storage_account_name = "tfstatea9911"
hub_backend_container_name       = "tfstate"

# spoke leaf 들 — 같은 SA 가리킴
spoke_backend_resource_group_name  = "terraform-state-rg"
spoke_backend_storage_account_name = "tfstatea9911"
spoke_backend_container_name       = "tfstate"
```

→ 결과적으로 단일 SA 안에 hub/spoke 모든 leaf 의 state 가 다른 key 로 보관됨.

코드(`hub_backend_*`, `spoke_backend_*` 변수)는 두 모드 모두 지원하므로,
**leaf tfvars 의 backend 이름 값**이 어느 SA 를 가리키느냐로 결정된다.

## 실행 절차

```bash
cd <repo-root>
source scripts/import/env.sh

# Hub 구독으로 SP 로그인 (env.sh 의 HUB_SUBSCRIPTION_ID 가 셋되어 있어야 함)
export ARM_SUBSCRIPTION_ID="$HUB_SUBSCRIPTION_ID"
./scripts/import/az-sp-login.sh

cd azure/hub/00.state-backend
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars               # hub_subscription_id 입력

terraform init                         # backend.tf 없음 → local state
terraform plan                         # Plan: 3 to add
terraform apply -auto-approve

terraform output                       # RG/SA/Container 이름 출력
```

출력된 이름들을 모든 Hub leaf 의 `terraform.tfvars` 에 다음 변수로 셋:

```hcl
hub_backend_resource_group_name  = "terraform-state-hub-rg"
hub_backend_storage_account_name = "tfstatehuba9911"
hub_backend_container_name       = "tfstate"
```

## 산출

| 리소스 | 기본 이름 | 비고 |
|---|---|---|
| Resource Group | `terraform-state-hub-rg` | Hub 구독 내 |
| Storage Account | `tfstatehuba9911` | 글로벌 unique. 충돌 시 tfvars 에서 변경 |
| Blob Container | `tfstate` | private, AAD/key 둘 다 허용 |

추가 보호:
- `versioning_enabled = true`
- `min_tls_version = TLS1_2`
- `allow_nested_items_to_be_public = false`
- Tag: `Side = hub`

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
    resource_group_name  = "terraform-state-hub-rg"
    storage_account_name = "tfstatehuba9911"
    container_name       = "tfstate"
    key                  = "azure/dev/hub/00.state-backend/terraform.tfstate"
  }
}
EOF

terraform init -migrate-state
```

## 삭제 시 주의

`terraform destroy` 하면 모든 Hub leaf 의 state 가 사라진다. **운영에서는 절대 금지.**
부득이한 경우엔 전 leaf state 백업 또는 다른 SA 로 마이그레이션 후 진행할 것.
