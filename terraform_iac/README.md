# terraform_iac

실제 인프라 배포를 담당하는 **IaC 루트**입니다.

- **Provider 설정**, **Backend(State) 설정**, **환경별 변수**를 여기서 관리합니다.
- **공통 모듈**은 **terraform-modules 레포**에서만 관리하며, 이 레포에서는 `ref=<태그>`로만 참조합니다.
  - 예: `source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/log-analytics-workspace?ref=v1.0.0"`
- **IaC 전용 모듈**은 이 레포의 `./modules/` (예: `./modules/dev/hub/vnet`, `./modules/dev/spoke/vnet`) 에 있습니다.
- `terraform plan` / `terraform apply`는 루트에서 실행합니다.

**main.tf에서 참조하는 공통 모듈 (terraform-modules 레포):**
- `log-analytics-workspace` — Log Analytics Workspace
- `vnet-peering` — Hub→Spoke Peering
- `virtual-machine` — Monitoring VM
