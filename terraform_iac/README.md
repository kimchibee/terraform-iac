# terraform_iac

실제 인프라 배포를 담당하는 **IaC 루트 디렉터리**입니다.

- **Provider 설정**, **Backend(State) 설정**, **환경별 변수**를 여기서 관리합니다.
- **terraform_modules**의 모듈을 `ref=<태그>`로 참조하여 사용합니다.
- `terraform plan` / `terraform apply`는 이 디렉터리(또는 환경별 하위 디렉터리)에서 실행합니다.

공통 모듈은 `terraform_modules` 저장소(또는 동일 저장소 내 `../terraform_modules`)를 참조하세요.
