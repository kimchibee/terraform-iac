# terraform_iac

실제 인프라 배포를 담당하는 **IaC 루트 디렉터리**입니다.

- **Provider 설정**, **Backend(State) 설정**, **환경별 변수**를 여기서 관리합니다.
- **공통 모듈**은 **terraform-modules 레포**를 `ref=<태그>`로 참조하여 사용합니다.
  - 예: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/vnet?ref=v1.0.0"`
- `terraform plan` / `terraform apply`는 루트(또는 환경별 하위 디렉터리)에서 실행합니다.

현재 루트 `main.tf`는 레거시 `./modules/`를 사용 중이며, 신규 모듈(resource-group, vnet, storage-account 등) 도입 시 위 git 소스로 전환하면 됩니다.
