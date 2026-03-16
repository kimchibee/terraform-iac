# Network

network 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개(`azure/dev/network/terraform.tfstate`), 하위 디렉터리(hub-vnet, spoke-vnet)는 **모듈**로만 호출합니다.

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

아래 블록을 **순서대로** 터미널에 복사해 붙여넣기만 하면 됩니다. 프로젝트 루트(`terraform-iac/`)에서 시작한다고 가정합니다.

**1단계: 스택 디렉터리로 이동 후 변수 파일 복사**
```bash
cd azure/dev/network
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
에디터로 `terraform.tfvars`를 열어 다음만 본인 환경에 맞게 바꿉니다.
- `hub_subscription_id`, `spoke_subscription_id` → 구독 ID (`az account list --query "[].{name:name, id:id}" -o table` 로 확인)
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name` → Bootstrap 적용 후 나온 값(또는 `bootstrap/backend/terraform.tfvars`와 동일)
- `hub_vnet_address_space`, `hub_subnets`, `spoke_vnet_address_space`, `spoke_subnets` → 필요 시 주소/서브넷만 수정

**3단계: init / plan / apply (아래 한 블록 통째로 복사 후 실행)**
```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 프롬프트에 `yes` 입력하여 확정.

---

## 1. 배포 방식

```bash
cd azure/dev/network
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, hub/spoke 주소 공간, 서브넷, backend 변수 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** 없음 (최초 배포 스택 중 하나).  
- **다음 스택:** storage, shared-services, apim, ai-services, compute 등이 이 스택 state를 참조합니다.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/network
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, spoke_subscription_id, hub_vnet_address_space, hub_subnets, spoke_*, backend 변수 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
# apply 시 "yes" 입력하여 확정
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

`terraform apply` 실행 시 Terraform이 수행하는 흐름을 초심자 관점으로 정리합니다.

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | `backend.hcl`을 읽어 state 저장소(Azure Storage) 연결. state 키는 `azure/dev/network/terraform.tfstate`. | `backend.hcl`의 resource_group_name, storage_account_name, container_name, key |
| 2. 변수 로드 | 루트 모듈의 변수에 값 채움. `-var-file=terraform.tfvars`로 전달된 값이 사용됨. | `terraform.tfvars` → `variables.tf`에 정의된 변수 |
| 3. 구독 결정 | Hub 리소스(VNet, NSG 등)는 **Hub 구독**에, Spoke 리소스는 **Spoke 구독**에 생성됨. provider별로 구독이 나뉨. | `provider.tf`: `azurerm.hub` → `var.hub_subscription_id`, `azurerm.spoke` → `var.spoke_subscription_id` |
| 4. locals 계산 | `main.tf`의 `locals` 블록 실행. name_prefix, hub_resource_group_name, hub_subnet_names, spoke_subnets 등 계산. | `var.project_name`, `var.hub_subnets`, `var.spoke_subnets` (tfvars에서 옴) |
| 5. hub_vnet 모듈 | `module "hub_vnet"` 호출 → `./hub-vnet` 디렉터리 실행. Hub VNet, 서브넷, VPN Gateway, DNS Resolver, NSG(Monitoring-VM, pep) 등 생성. | `local.hub_resource_group_name`, `local.hub_subnets`, `var.hub_vnet_address_space` 등. 구독은 `azurerm.hub`(hub_subscription_id) |
| 6. spoke_vnet 모듈 | `module "spoke_vnet"` 호출 → `./spoke-vnet` 실행. Spoke VNet, 서브넷(apim-snet, pep-snet), Hub와 피어링 생성. | `module.hub_vnet.vnet_id`, `module.hub_vnet.private_dns_zone_ids` 등. 구독은 `azurerm.spoke`(spoke_subscription_id) |
| 7. keyvault_sg 모듈 (옵션) | `enable_keyvault_sg = true`일 때만. keyvault-sg NSG·규칙, PE 인바운드용 ASG 등 생성. | `var.enable_keyvault_sg`, `var.hub_nsg_keys_add_keyvault_rule`, `module.hub_vnet.nsg_pep_id` 등 |
| 8. vm_access_sg 모듈 (옵션) | `enable_vm_access_sg = true`일 때만. vm-allowed-clients ASG 및 타겟 NSG 인바운드 규칙 생성. | `var.enable_vm_access_sg`, `var.vm_access_target_nsg_keys`, `module.hub_vnet.nsg_monitoring_vm_id` 등 |
| 9. Output 기록 | `outputs.tf`에 정의된 값(hub_resource_group_name, hub_subnet_ids, keyvault_clients_asg_id 등)이 state에 기록됨. 다른 스택이 remote_state로 이 값을 읽음. | 각 모듈 output 및 루트 output |

**정리:** 구독 ID는 `terraform.tfvars`의 `hub_subscription_id` / `spoke_subscription_id`로 정해지고, `provider.tf`에서 각 provider에 연결됩니다. VNet/서브넷 ID는 이 스택이 **직접 생성**하므로 외부 참조 없이, 루트의 `locals`와 `var.hub_subnets` 등으로 결정됩니다.

### 2.3 terraform apply 시 파일 참조 순서

Terraform이 설정을 읽고 리소스를 만드는 데 참조하는 파일·순서는 대략 다음과 같습니다.

1. **backend.hcl** (init 시) — state 저장소 위치·키 결정.
2. **provider.tf** — required_providers 및 provider 블록. 구독 ID는 여기서 사용하는 변수(`var.hub_subscription_id`, `var.spoke_subscription_id`)로 결정.
3. **variables.tf** — 루트 모듈 변수 정의. 기본값이 있으면 여기서 지정.
4. **terraform.tfvars** (또는 -var, -var-file) — 변수에 넣을 실제 값. variables.tf보다 **나중에** 적용되어 기본값을 덮어씀.
5. **main.tf** — 진입점. `locals` 계산 후 `module "hub_vnet"`, `module "spoke_vnet"` 등 호출. **remote_state 데이터 소스는 이 스택에 없음**(선행 스택 없음).
6. **./hub-vnet/** — `main.tf`의 `module "hub_vnet"`이 `source = "./hub-vnet"`로 참조. hub-vnet 내부의 `main.tf`, `variables.tf`, `versions.tf` 및 Git 모듈(terraform-modules) 참조.
7. **./spoke-vnet/** — `module "spoke_vnet"`이 `source = "./spoke-vnet"`로 참조.
8. **./keyvault-sg/** — `enable_keyvault_sg`일 때만 `module "keyvault_sg"`가 참조.
9. **./vm-access-sg/** — `enable_vm_access_sg`일 때만 `module "vm_access_sg"`가 참조.
10. **outputs.tf** — output 값 계산 후 state에 기록.

---

## 3. 추가 가이드 (신규 Spoke VNet·서브넷 등 추가)

**공통 절차 (신규 인스턴스 추가 시)**  
(1) 예시 디렉터리 복사 → (2) 필요 시 새 디렉터리 내 기본값 수정 → (3) 루트 `main.tf`에 module 블록 추가 → (4) 루트 `variables.tf`에 변수 추가 → (5) `terraform.tfvars`에 값 설정 → (6) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **신규 Spoke VNet 추가**  
  1. `spoke-vnet` 디렉터리를 복사해 새 이름 생성 (예: `spoke-vnet-02`). (복사 후 **spoke-vnet 폴더 내 수정 가이드**는 `spoke-vnet/main.tf` 상단 주석 참고.)  
  2. 루트 `main.tf`의 `locals`에 02용 이름/서브넷 추가 후, `module "spoke_vnet_02" { source = "./spoke-vnet-02"; ... }` 블록 추가.  
  3. 루트 `variables.tf`에 해당 스택용 변수 정의 (예: `spoke_02_vnet_address_space`, `spoke_02_subnets`).  
  4. `terraform.tfvars`에 값 설정.  
  5. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

- **Hub 쪽 리소스(서브넷·VPN 등) 추가**  
  디렉터리 복사 없이 **변수·로컬만 반영**: 루트 `main.tf`의 `locals` 또는 `module "hub_vnet"` 인자, 그리고 `variables.tf`·`terraform.tfvars`에 반영 후 **이 스택 루트에서** plan → apply.  
  공통 모듈(hub-vnet)에 인자가 없으면 terraform-modules 레포에 반영 후 `terraform init -upgrade` → plan → apply.

- **시나리오 3: keyvault-sg (Key Vault 접근 허용 NSG)**  
  1. `terraform.tfvars`에서 `enable_keyvault_sg = true` 설정.  
  2. **기존 Hub NSG에 규칙만 추가**할 때: `hub_nsg_keys_add_keyvault_rule = ["monitoring_vm"]` (또는 `["pep"]`, `["monitoring_vm", "pep"]`).  
  3. **Standalone keyvault-sg NSG를 서브넷에 연결**할 때: `hub_subnet_names_attach_keyvault_sg = ["서브넷이름"]` (이미 다른 NSG가 붙어 있는 서브넷에는 사용 불가 — Azure는 서브넷당 NSG 1개).  
  4. **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.  
  - **Key Vault PE 위치:** storage 스택의 monitoring-storage 모듈이 Hub VNet **pep-snet**에 Key Vault Private Endpoint를 생성.  
  - **UDR:** PE가 동일 VNet(Hub)에 있으므로 Hub 내 서브넷은 별도 UDR 없이 라우팅됨. Spoke → Hub Key Vault 접근은 VNet 피어링으로 처리.

- **한 정책으로 Monitoring VM + Spoke Linux 허용 (다른 VNet)**  
  - **인바운드 1개:** 소스 = 시큐리티 그룹(ASG), 포트 443.  
  - `enable_pe_inbound_from_asg = true` 로 두면, keyvault-clients ASG가 생성되고 **PE(pep-snet) NSG에 인바운드 규칙 1개**가 추가됨.  
  - Network 스택 output `keyvault_clients_asg_id`를 compute 스택으로 전달한 뒤, **Monitoring VM·Spoke Linux VM NIC**에 `application_security_group_ids = [keyvault_clients_asg_id]` 로 붙이면, **정책 1개**로 둘 다 Key Vault 접근 가능.  
  - 자세한 설명: 로컬 `docs/` 또는 프로젝트 문서(시나리오 3 Key Vault 접근 정책) 참고.

- **VM 타겟 단일 방화벽 정책 (ASG)**  
  - **일반 VM**에 접속 허용할 클라이언트를 ASG 하나로 묶고, 타겟 VM NSG에 **인바운드 1개**(소스=ASG, 포트 22/3389 등)만 두면 VNet 무관 단일 정책.  
  - `enable_vm_access_sg = true`, `vm_access_target_nsg_keys = ["monitoring_vm"]` (Hub 타겟), 필요 시 `vm_access_target_nsg_ids_spoke = ["/subscriptions/.../nsg-id"]` (Spoke 타겟).  
  - output `vm_allowed_clients_asg_id`를 **접속 허용할 클라이언트 VM** NIC에 `application_security_group_ids` 로 붙임.  
  - NSG/ASG 관리 위치 의견: 로컬 `docs/` 또는 프로젝트 문서(네트워크 보안 관리) 참고 (RBAC가 아닌 network 스택 권장).

---

## 4. 변경 가이드 (기존 리소스 수정)

- **주소 공간·서브넷·VPN 설정 등**  
  `terraform.tfvars`(및 필요 시 `variables.tf`)에서 `hub_vnet_address_space`, `hub_subnets`, `spoke_vnet_address_space`, `spoke_subnets`, `vpn_gateway_sku` 등 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- **이름·로컬 값 변경**  
  루트 `main.tf`의 `locals` 또는 모듈 인자 수정 후 plan → apply.

- **keyvault-sg(시나리오 3) 변경**  
  `hub_nsg_keys_add_keyvault_rule`, `hub_subnet_names_attach_keyvault_sg` 수정 후 plan → apply.

- **vm-access-sg 변경**  
  `vm_access_target_nsg_keys`, `vm_access_target_nsg_ids_spoke`, `vm_access_destination_ports` 수정 후 plan → apply.

- 일부 변경은 리소스 **replace**를 유발할 수 있으므로 plan 결과를 확인한 뒤 적용합니다.

---

## 5. 삭제 가이드 (리소스 제거)

- **Spoke VNet 하나 제거**  
  1. 루트 `main.tf`에서 해당 `module "spoke_vnet_xx" { ... }` 블록 삭제.  
  2. 관련 변수·output 제거 또는 주석 처리.  
  3. `terraform plan` → `apply`로 destroy 적용.  
  4. (선택) 해당 하위 디렉터리 삭제.

- **Hub VNet 제거**  
  다른 스택이 hub 출력을 참조하므로, 선행하여 해당 스택들(storage, compute, connectivity 등)을 정리한 뒤 network에서 제거합니다.

- **keyvault-sg(시나리오 3) 비활성화**  
  `enable_keyvault_sg = false`로 설정 후 plan → apply. 기존 NSG에 추가된 Allow KeyVault 규칙은 수동 삭제하거나, 규칙만 제거하려면 `hub_nsg_keys_add_keyvault_rule = []`로 비운 뒤 apply.

- **vm-access-sg 비활성화**  
  `enable_vm_access_sg = false`로 설정 후 plan → apply. 기존 타겟 NSG에 추가된 AllowVMClients 규칙은 수동 삭제 가능.

- **state에서만 제거**  
  `terraform state rm 'module.xxx'` 사용 (Azure 리소스는 그대로 둘 때만).

---

## 6. 하위 모듈

| 디렉터리 | 역할 |
|----------|------|
| **hub-vnet/** | Hub VNet, VPN Gateway, DNS Resolver 등 (Git hub-vnet 래핑) |
| **spoke-vnet/** | Spoke VNet (Git spoke-vnet 래핑, Hub 출력을 변수로 수신) |
| **keyvault-sg/** | 시나리오 3: Key Vault(443) 아웃바운드 허용 NSG 규칙 (standalone NSG 또는 기존 Hub NSG에 규칙 추가) |
| **vm-access-sg/** | VM 타겟 단일 정책: ASG + 타겟 VM NSG 인바운드(소스=ASG, 22/3389 등). 클라이언트 NIC에 ASG 붙이면 VNet 무관 허용 |
