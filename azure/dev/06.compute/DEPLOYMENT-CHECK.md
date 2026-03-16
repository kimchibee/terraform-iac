# Compute 스택 배포 구조 검증 결과

## 검증 일시
배포 구조 변경(01.network 등 디렉터리/state key) 후 compute만 배포 시 이슈 여부 확인.

## 결과: **배포 구조 변경으로 인한 이슈 없음**

### 1. remote_state 설정
- **06.compute** `main.tf`의 `data "terraform_remote_state" "network"`:
  - `key = "azure/dev/01.network/terraform.tfstate"` → **01.network** 스택 state 경로와 일치.

### 2. Output 참조 일치
| Compute에서 참조 (main.tf) | 01.network outputs.tf |
|---------------------------|------------------------|
| `hub_resource_group_name` | ✅ `output "hub_resource_group_name"` |
| `hub_subnet_ids["Monitoring-VM-Subnet"]` | ✅ `output "hub_subnet_ids"` |
| `keyvault_clients_asg_id` | ✅ `output "keyvault_clients_asg_id"` (try(..., null) 사용) |
| `vm_allowed_clients_asg_id` | ✅ `output "vm_allowed_clients_asg_id"` (try(..., null) 사용) |

위 출력은 모두 01.network에 정의되어 있으며, 이름·구조 변경 없음.

### 3. Plan 실행 시 나온 에러에 대해
- **에러:** `data.terraform_remote_state.network.outputs is object with no attributes`  
  (e.g. `hub_resource_group_name` / `hub_subnet_ids` 없음)
- **원인:** `terraform.tfvars`가 없어 **terraform.tfvars.example**으로 plan을 실행함.  
  example의 `backend_*` 값이 **실제 01.network를 적용한 state 저장소와 다르거나**, 해당 key에 state가 없어서 읽은 state에 outputs가 비어 있음.
- **결론:** 코드/구조 문제가 아니라, **실제 배포 시에는 01.network와 동일한 backend를 쓰는 terraform.tfvars**를 사용하면 정상 동작함.

### 4. Compute만 배포할 때
1. **01.network**는 이미 적용된 상태여야 함 (state에 outputs 기록됨).
2. **06.compute**에서:
   - `terraform.tfvars`를 준비 (01.network와 동일한 `backend_*`, 본인 구독 ID, 필요 시 Windows 비밀번호 등).
   - `terraform init -backend-config=backend.hcl`
   - `terraform plan -var-file=terraform.tfvars`
   - `terraform apply -var-file=terraform.tfvars` (또는 `-auto-approve`)

이 순서로 진행하면 배포 구조 변경으로 인한 추가 이슈는 없음.
