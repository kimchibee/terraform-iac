# Connectivity 배포 가이드

Hub ↔ Spoke VNet Peering 및 Hub 측 진단 설정(진단 로그 수집)을 관리하는 스택입니다.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/connectivity
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name` | 리소스 접두사 (진단 설정 이름 등에 사용) | 프로젝트 규칙 (예: `test`) |
| `hub_subscription_id` | Hub 구독 ID | Azure Portal: **구독** → 사용할 구독 → **구독 ID** 복사. 또는 `az account show --query id -o tsv` |
| `spoke_subscription_id` | Spoke 구독 ID | 동일하게 Azure Portal 또는 `az account list -o table` 후 해당 구독의 ID |
| `backend_resource_group_name` | Backend 스토리지가 있는 리소스 그룹 이름 | **Bootstrap** 스택 배포 후 `bootstrap/backend/terraform.tfvars`에 적은 `resource_group_name` 값 (예: `terraform-state-rg`) |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | 위와 동일하게 Bootstrap의 `terraform.tfvars`에 있는 `storage_account_name` (예: `tfstate07dc60`) |
| `backend_container_name` | State Blob 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/connectivity
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

이 스택은 **리소스를 새로 만드는 것이 아니라**, 이미 **network / storage 스택**에서 만든 리소스에 **Peering과 진단 설정**만 붙입니다.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| VNet Peering | Hub → Spoke | 1 | `{hub_vnet_name}-to-spoke` (network 스택 출력의 `hub_vnet_name` 사용) |
| VNet Peering | Spoke → Hub | 1 | `{spoke_vnet_name}-to-hub` (network 스택 출력의 `spoke_vnet_name` 사용) |
| Diagnostic Setting | VPN Gateway | 1 | `{hub_vnet_name}-vpng-storage-diag` (대상: network의 `hub_vpn_gateway_id`) |
| Diagnostic Setting | Hub VNet | 1 | `{hub_vnet_name}-storage-diag` (대상: network의 `hub_vnet_id`) |
| Diagnostic Setting | Monitoring VM NSG | 1 | `{project_name}-nsg-monitoring-diag` (대상: network의 `hub_nsg_monitoring_vm_id`) |
| Diagnostic Setting | Hub pep NSG | 1 | `{project_name}-nsg-pep-diag` (대상: network의 `hub_nsg_pep_id`) |

- **VNet / 서브넷 / NSG / VPN Gateway** 자체는 **network** 스택에서 생성됩니다.  
- **Storage 계정**(진단 로그 저장 대상)은 **storage** 스택에서 생성됩니다.  
- 이 스택에서 생성되는 것은 **Peering 2개 + 진단 설정 4개**뿐입니다.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: 진단 설정 1개 더 붙이기)

1. `main.tf`에 `azurerm_monitor_diagnostic_setting` 리소스 블록을 추가합니다.  
2. `target_resource_id`는 `data.terraform_remote_state.network.outputs.*` 또는 `data.terraform_remote_state.storage.outputs.*`에서 참조합니다.  
3. `storage_account_id`는 `data.terraform_remote_state.storage.outputs.monitoring_storage_account_ids["xxx"]` 등 기존 계정을 사용하거나, storage 스택에 새 계정이 있으면 해당 키를 사용합니다.  
4. 저장 후 아래 순서로 적용합니다.

```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **공통 모듈에 없는 리소스 타입**이면 **3.4 모듈 레포 수정**을 먼저 진행한 뒤, 이 스택에서 `module`로 참조하거나 로컬 `resource`로 추가합니다.

### 3.2 기존 리소스 변경 (예: Peering 옵션, 진단 로그 카테고리)

1. `main.tf` 또는 해당 모듈 인자에서 옵션을 수정합니다.  
2. `terraform plan -var-file=terraform.tfvars`로 변경 내용을 확인한 뒤 `terraform apply -var-file=terraform.tfvars`로 적용합니다.  
3. 모듈 인자를 바꾸는 경우: 모듈 소스가 `terraform-modules` 레포라면, **모듈 쪽에서 변수/인자 지원이 있어야** 합니다. 필요 시 **3.4** 참고.

### 3.3 기존 리소스 삭제

1. 제거할 `resource` 또는 `module` 블록을 `main.tf`에서 삭제(또는 주석 처리)합니다.  
2. `terraform plan -var-file=terraform.tfvars`로 destroy 대상이 의도한 것인지 확인합니다.  
3. `terraform apply -var-file=terraform.tfvars`로 적용하면 해당 리소스만 Azure에서 제거됩니다.  
4. state에서만 제거하고 Azure 리소스는 남기려면 `terraform state rm '주소'` 사용 (주의해서 진행).

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

**상황:** 신규 리소스가 필요한데, 현재 공통 모듈에 해당 템플릿이 없음.  
예: vnet-peering 모듈에 옵션 추가, 또는 새 리소스 타입을 모듈로 추가해야 하는 경우.

1. **terraform-modules 레포에서 작업**
   - `terraform-modules` 레포를 clone하고, 해당 모듈 디렉터리(예: `terraform_modules/vnet-peering`)에서 수정합니다.
   - 새 리소스 추가 또는 기존 리소스에 변수/옵션 추가 후, 테스트용 `terraform plan`으로 문법·의존성 확인합니다.
   - 변경 사항을 커밋하고 원격(예: `main`)에 push합니다.

2. **이 스택(connectivity)에서 모듈 참조 갱신 후 배포**
   - connectivity 디렉터리에서 **반드시** 아래 순서로 진행합니다.
   - **업그레이드:** 원격 모듈 최신 버전을 가져옵니다.  
     `terraform init -backend-config=backend.hcl -upgrade`
   - **플랜:** 변경 내용을 확인합니다.  
     `terraform plan -var-file=terraform.tfvars`
   - **배포:** 문제 없으면 적용합니다.  
     `terraform apply -var-file=terraform.tfvars`

3. **모듈 소스가 Git인 경우**
   - `source = "git::https://github.com/...?ref=main"` 이면 `init -upgrade` 시 최신 `main`을 가져옵니다.
   - 특정 태그/브랜치를 쓰는 경우 해당 ref를 올린 뒤 동일하게 `init -upgrade` → `plan` → `apply` 순서를 유지합니다.

**요약:** 공통 모듈에 없는 템플릿이 필요할 때는 **먼저 모듈 레포에 작성/수정 → push → 각 스택에서 init -upgrade → plan → apply** 순서로 진행하면 됩니다.
