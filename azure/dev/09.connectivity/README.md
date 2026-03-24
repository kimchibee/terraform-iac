# Connectivity (09)

Hub ↔ Spoke **VNet Peering**과 Hub 측 **모니터링 진단 설정**을 관리합니다.  
**`peering/`**, **`diagnostics/`** 아래의 **리프 디렉터리**에서만 `terraform plan` / `apply`를 실행합니다. (리프마다 State 1개.)

## 리프 구조

| 분류 | 리프 경로 (`azure/dev/` 기준) | Backend `key` | 내용 |
|------|------------------------------|-----------------|------|
| peering | `09.connectivity/peering/hub-to-spoke` | `azure/dev/09.connectivity/peering/hub-to-spoke/terraform.tfstate` | Hub 구독에서 Hub→Spoke 피어링 (`azurerm.hub`) |
| peering | `09.connectivity/peering/spoke-to-hub` | `azure/dev/09.connectivity/peering/spoke-to-hub/terraform.tfstate` | Spoke 구독에서 Spoke→Hub 피어링 (`azurerm.spoke`) |
| diagnostics | `09.connectivity/diagnostics/hub` | `azure/dev/09.connectivity/diagnostics/hub/terraform.tfstate` | VPN Gateway·VNet·NSG 진단 설정 (Hub 구독) |

- 상위 `09.connectivity/` 및 `peering/`, `diagnostics/` 폴더에는 Terraform 루트가 없습니다. **apply는 리프에서만** 수행합니다.
- `scripts/generate-backend-hcl.sh`의 `CONNECTIVITY_LEAVES`에 위 경로가 등록되어 있습니다.

## 선행 조건

- **network_hub** (`01.network/vnet/hub-vnet`), **network_spoke** (`01.network/vnet/spoke-vnet`) — Hub/Spoke VNet·VPN Gateway·NSG ID 등.
- **storage** (`02.storage/monitoring`) — 모니터링 Storage 계정(진단 로그 수집용). 진단 리프는 `monitoring_storage_account_ids`가 비어 있으면 진단 리소스를 생성하지 않습니다 (`count = 0`).
- 피어링 두 리프는 **서로 다른 구독**에서 provider가 달라야 하므로, `hub-to-spoke`는 Hub 구독, `spoke-to-hub`는 Spoke 구독으로 `az login` 또는 `ARM_SUBSCRIPTION_ID` 등이 맞는지 확인합니다.

## 권장 적용 순서

1. `peering/hub-to-spoke`
2. `peering/spoke-to-hub`  
   (순서를 바꿔도 되는 경우가 많으나, 한쪽만 적용된 중간 상태는 피어링이 완성되지 않습니다.)
3. `diagnostics/hub`

## 각 리프 공통 명령

프로젝트 루트에서 Bootstrap 및 `./scripts/generate-backend-hcl.sh` 실행 후, 리프 디렉터리에서:

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 기존 단일 `08.connectivity` state에서 이전하는 경우

이전에 **`azure/dev/08.connectivity/terraform.tfstate`**(단일 스택) 한 개에 피어링·진단이 모두 있었다면, 리소스를 세 state로 나누려면 `terraform state mv`로 주소를 각 리프로 옮기거나, 빈 환경이면 새 리프에 `apply`로 재생성합니다. 대략적인 주소 예시:

| 이전 주소 (단일 스택) | 이전 대상 리프 |
|----------------------|----------------|
| `module.vnet_peering_hub_to_spoke.*` | `09.connectivity/peering/hub-to-spoke` |
| `module.vnet_peering_spoke_to_hub.*` | `09.connectivity/peering/spoke-to-hub` |
| `azurerm_monitor_diagnostic_setting.hub_*` | `09.connectivity/diagnostics/hub` |

실제 모듈·리소스 주소는 `terraform state list`로 확인한 뒤 맞춥니다.

## 변수 파일

- **`peering/hub-to-spoke`**: `hub_subscription_id`, `backend_*`  
- **`peering/spoke-to-hub`**: `spoke_subscription_id`, `backend_*`  
- **`diagnostics/hub`**: `project_name`, `hub_subscription_id`, `backend_*`  

단일 스택에 쓰던 `terraform.tfvars`를 그대로 쓸 수 없습니다. 리프별 예시는 각 폴더의 `terraform.tfvars.example`를 참고합니다.
