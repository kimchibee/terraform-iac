# terraform_modules

terraform-infra 저장소에서 **공통으로 사용하는 재사용 가능한 Terraform 모듈**을 관리하는 라이브러리입니다.

이 저장소는 **실제 인프라를 직접 생성하지 않습니다.**  
Azure 리소스 생성과 상태(State) 관리는 **terraform-infra**(또는 `terraform_iac`)에서 수행합니다.

---

## 목표

| 목표 | 설명 |
|------|------|
| **코드 공통화** | 반복되는 Terraform 코드를 모듈로 추출하여 재사용 |
| **일관성** | Azure 리소스를 일관된 방식으로 생성 |
| **환경 분리** | 환경(dev / stage / prod)과 완전히 분리된 설계 — 모듈은 환경에 의존하지 않음 |
| **예측 가능성** | 장기 운영 시 변경 영향이 예측 가능한 구조 유지 |

---

## 설계 원칙

1. **단일 책임**  
   각 모듈은 **하나의 역할만** 담당합니다. (예: VNet 전용, Storage Account 전용)

2. **라이브러리 전용**  
   이 저장소에는 Provider 설정, Backend 설정, `terraform apply` 대상 루트 모듈을 두지 않습니다.

3. **환경 무관**  
   모듈 내부에서 `dev` / `stage` / `prod`를 하드코딩하지 않습니다. 환경별 값은 terraform-infra에서 변수로 주입합니다.

4. **입·출력 명확**  
   `variables.tf`와 `outputs.tf`로 인터페이스를 명확히 하고, 필요한 값만 노출합니다.

---

## 버전 관리 정책 (Versioning)

- 이 저장소는 **Git Tag 기반 버전 관리**를 사용합니다.
- **terraform-infra에서는 반드시 특정 태그(ref)를 지정**하여 모듈을 참조해야 합니다.
- `main` / `master` 등 브랜치 이름을 직접 참조하지 않습니다. (변경 사항이 예측 불가능해짐)

### 사용 예시 (terraform-infra 쪽)

```hcl
module "vnet" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/vnet?ref=v1.2.0"

  resource_group_name = var.resource_group_name
  location            = var.location
  vnet_name           = local.vnet_name
  vnet_address_space  = ["10.0.0.0/16"]
  subnets             = var.subnets
  project_name        = var.project_name
  environment         = var.environment
  tags                = var.tags
}
```

- `ref=v1.2.0` 처럼 **태그를 명시**하여 사용합니다.
- 버전 변경 시 배포 전 검토가 가능하고, 롤백 시 이전 태그로 되돌리면 됩니다.

---

## 디렉터리 구조

```
terraform_modules/
├── README.md           # 이 문서
├── VERSIONING.md       # 버전 관리 상세 정책
├── MODULE_REVIEW.md    # 모듈 검토·스케일아웃 vs 단일/SaaS 정책
├── resource-group/     # Resource Group 1개
├── vnet/               # Virtual Network + 서브넷
├── storage-account/    # Storage Account 1개
├── key-vault/          # Key Vault 1개 (PE는 private-endpoint 모듈 사용)
├── private-endpoint/   # Private Endpoint 1개 + (선택) DNS Zone 연결
└── ...                 # 그 외 단일 책임 모듈 (diagnostic-settings, nsg 등)
```

각 모듈 디렉터리에는 다음을 포함합니다.

- `main.tf` — 리소스 정의
- `variables.tf` — 입력 변수
- `outputs.tf` — 출력 값 (다른 모듈/루트에서 참조용)

---

## 모듈 추가 시 체크리스트

- [ ] 하나의 역할만 담당하는가?
- [ ] 환경(dev/stage/prod)을 하드코딩하지 않았는가?
- [ ] `variables.tf` / `outputs.tf`로 인터페이스가 명확한가?
- [ ] README 또는 주석으로 사용법을 남겼는가?
- [ ] 배포 전 **새 버전 태그**를 붙일 예정인가?

---

## terraform-infra와의 관계

```
┌─────────────────────────────────────────────────────────────────┐
│  terraform-infra (또는 terraform_iac)                           │
│  - Provider / Backend 설정                                       │
│  - 환경별 tfvars (dev/stage/prod)                                │
│  - terraform plan / apply 실행                                   │
│  - State 보관                                                    │
│                                                                  │
│  module "vnet" {                                                 │
│    source = "...?ref=v1.2.0"   ← 항상 태그(ref) 지정             │
│    ...                                                            │
│  }                                                               │
└──────────────────────────────┬──────────────────────────────────┘
                               │ 참조
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│  terraform_modules (이 저장소)                                   │
│  - 재사용 가능한 모듈만 보관 (라이브러리)                         │
│  - 직접 apply 하지 않음                                          │
└─────────────────────────────────────────────────────────────────┘
```

이 문서는 terraform_modules의 역할, 목표, 버전 정책을 정의합니다.  
상세 버전 규칙은 [VERSIONING.md](./VERSIONING.md)를 참고하세요.
