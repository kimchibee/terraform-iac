# 00.state-backend — Terraform state backend 부트스트랩 (단일 SA 모드)

다른 모든 leaf 들이 state 파일을 저장할 **단일** Azure Storage Account 를 Terraform 으로
생성하는 **1회용 bootstrap 스택**. `backend.tf` 가 없어 자기 자신의 state 는 **로컬 파일**
(`./terraform.tfstate`) 로 보관된다.

> **모드 선택**:
> - 이 스택 (`azure/00.state-backend/`) — **단일 SA** 하나에 hub/spoke 양쪽 state 를 담는다 (현재 production: `tfstatea9911`)
> - `azure/hub/00.state-backend/` + `azure/spoke/00.state-backend/` — **분리 SA** 각 측면 별도. 구독 분리, 권한/blast-radius 분리 시나리오
>
> 두 모드는 leaf 의 `*_backend_storage_account_name` 변수 값이 어느 SA 를 가리키느냐로 결정된다. 단일 SA 모드를 쓰던 곳에서 분리로 전환하려면 leaf tfvars 의 backend 이름 일괄 변경 + state 마이그레이션 필요.

## 언제 실행하나

- 새로운 Azure 구독 또는 새 PC 환경에서 처음 import 작업을 시작할 때 **1회만**
- 이미 운영 환경에 storage account 가 존재하면 실행 불요 (현재 production 상태)
- `diagnose-storage-auth.sh` 결과가 `Storage account ... 가 존재하지 않음` 일 때

## 실행 절차

```bash
# 1) 환경 + 인증
cd <repo-root>
source scripts/import/env.sh
./scripts/import/az-sp-login.sh    # SP 로그인 (또는 az login)

# 2) tfvars 작성 (subscription_id 만 필수)
cd azure/00.state-backend
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars           # subscription_id 값 입력

# 3) Terraform 적용
terraform init                     # backend.tf 없음 → local state
terraform plan                     # 기대: 3 to add
terraform apply -auto-approve

# 4) 출력 확인
terraform output
# resource_group_name  = "terraform-state-rg"
# storage_account_name = "tfstatea9911"
# container_name       = "tfstate"
```

## 산출

| 리소스 | 기본 이름 | 비고 |
|---|---|---|
| Resource Group | `terraform-state-rg` | env.sh `TF_BACKEND_RG` 와 일치해야 함 |
| Storage Account | `tfstatea9911` | env.sh `TF_BACKEND_SA` 와 일치, 글로벌 unique |
| Blob Container | `tfstate` | env.sh `TF_BACKEND_CONTAINER` 와 일치 |

추가 보호:
- `versioning_enabled = true` — state blob 의 이전 버전 복원 가능 (실수 덮어쓰기 방지)
- `min_tls_version = TLS1_2`
- `allow_nested_items_to_be_public = false`

## state 파일 관리

이 스택은 자기 자신의 state 를 **로컬 파일**(`./terraform.tfstate`) 에 보관한다.

- 레포 루트 `.gitignore` 의 `*.tfstate` 패턴에 매칭되어 git 에 들어가지 않음
- **분실 시 영향**: 이후 변경(tags 수정 등) 시 `terraform import` 로 3 리소스를 재등록 필요
- 권장: `terraform.tfstate` 를 안전한 곳에 백업 (예: 비밀번호 관리자, 사내 sealed secret)

## 더 안전한 대안 — Self-hosted state migration

`terraform apply` 가 성공한 직후, state 를 방금 만든 SA 로 마이그레이션할 수 있다.
순환처럼 보이지만 자기 자신 3 리소스의 변경만 추적하므로 동작한다:

```bash
cat > backend.tf <<'EOF'
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatea9911"
    container_name       = "tfstate"
    key                  = "azure/dev/00.state-backend/terraform.tfstate"
  }
}
EOF

terraform init -migrate-state
# Prompt 에 yes 입력 → 로컬 state 가 SA 로 이전
# ./terraform.tfstate 는 빈 파일이 되고 실제 state 는 blob 에 존재
```

이 단계는 선택. local state 로 두고 백업으로만 관리해도 무방.

## 삭제 시 주의

이 스택을 `terraform destroy` 하면 모든 leaf 의 state 파일이 사라진다. **운영 환경에서는
절대 실행 금지.** 부득이한 경우엔 사전에 모든 leaf state 를 백업하거나 마이그레이션할 것.
