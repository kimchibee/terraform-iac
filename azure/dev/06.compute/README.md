# Compute (06) — 분류 폴더

VM·Managed Identity은 **VM 폴더 리프**에서만 `plan` / `apply` 합니다. (루트 `06.compute/`에는 Terraform 루트가 없습니다.)

| 리프 | State 키 |
|------|-----------|
| `06.compute/linux-monitoring-vm` | `azure/dev/06.compute/linux-monitoring-vm/terraform.tfstate` |
| `06.compute/windows-example` | `azure/dev/06.compute/windows-example/terraform.tfstate` |

- Linux 모니터링 VM은 **storage**·**08.rbac** 등에서 `monitoring_vm_identity_principal_id` 출력으로 참조됩니다.
- 배포 순서 예: `01.network/vnet/hub-vnet` → `01.network/subnet/hub-pep-subnet`(ASG 사용 시) → `01.network/vnet/spoke-vnet` → `02.storage/monitoring` → `linux-monitoring-vm` → `08.rbac/principal/*`(필요 시) → `windows-example` 등.

각 리프의 `README.md`·`terraform.tfvars.example`을 참고하세요.
