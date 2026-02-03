# Terraform Modules (공통 모듈)

Azure 인프라용 **재사용 가능한 Terraform 모듈** 라이브러리입니다.  
**이 레포에는 공통 모듈만** 있으며, 직접 `terraform apply` 하지 않고 **[terraform-iac](https://github.com/kimchibee/terraform-iac)** 등 IaC 레포에서 `source = "git::..."` 로 참조해 사용합니다.

---

## 이 레포에서 관리하는 것

| 구분 | 내용 |
|------|------|
| **모듈 위치** | `terraform_modules/` — 모든 공통 모듈이 이 디렉터리 아래에 있음. |
| **버전** | Git 브랜치·태그 기반. IaC에서는 `?ref=main` 또는 `?ref=v1.0.0` 등으로 참조. |
| **역할** | 단일 책임, 환경 무관, 라이브러리 전용. |

---

## 참조 방법 (terraform-iac 등에서)

**공통 모듈 참조는 IaC 레포의 `main.tf`에만 있습니다.**

- **형식**: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"`
- **태그 사용 시**: `?ref=main` 대신 `?ref=v1.0.0` 등으로 지정.
- **예시**  
  - Log Analytics: `//terraform_modules/log-analytics-workspace?ref=main`  
  - VNet Peering: `//terraform_modules/vnet-peering?ref=main`  
  - Virtual Machine: `//terraform_modules/virtual-machine?ref=main`

---

## 디렉터리 구조

```
terraform-modules/
├── README.md
├── .gitignore
└── terraform_modules/
    ├── log-analytics-workspace/
    ├── virtual-machine/
    ├── vnet-peering/
    ├── nsg/
    ├── diagnostic-settings/
    ├── private-dns-zone/
    └── ... (기타 공통 모듈)
```

각 하위 모듈에는 `main.tf`, `variables.tf`, `outputs.tf`, `README.md` 등이 포함됩니다.

---

## terraform-iac와의 관계

- **terraform-iac**: 루트 모듈, Provider/Backend, **IaC 전용 모듈**(`modules/dev/hub`, `modules/dev/spoke`) 보유. 배포는 terraform-iac 루트에서 실행.
- **terraform-modules (이 레포)**: 공통 모듈만 보유. terraform-iac의 `main.tf`에서 `git::...terraform-modules.git//terraform_modules/모듈명?ref=...` 로 참조.

공통 모듈을 추가·수정할 때는 **이 레포(terraform-modules)** 만 변경하고, IaC 레포에서는 `source` 의 `ref=` 만 필요 시 변경하면 됩니다.

---

## 버전(태그) 사용 (선택)

태그를 배포하면 IaC에서 고정 버전으로 참조할 수 있습니다.

```bash
git tag v1.0.0
git push origin v1.0.0
```

IaC의 `main.tf` 예: `source = "git::...//terraform_modules/log-analytics-workspace?ref=v1.0.0"`

자세한 버전 정책은 `terraform_modules/README.md` 또는 `terraform_modules/VERSIONING.md` 를 참고하세요.
