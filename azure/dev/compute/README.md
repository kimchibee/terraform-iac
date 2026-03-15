# Compute

compute 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개(`azure/dev/compute/terraform.tfstate`), 하위 디렉터리(linux-monitoring-vm, windows-example 등)는 **모듈**로만 호출합니다.

---

## 0. 전체 배포 리소스 일람 (스택별)

선행 스택까지 배포 완료 시 생성·관리되는 리소스를 스택 순서대로 정리한 표입니다. (`project_name` = `test` 기준, 접두사 `test-x-x`)

| 스택 | 구독 | 리소스 종류 | 리소스 이름(예시) | 비고 |
|------|------|-------------|-------------------|------|
| **Bootstrap** | Hub | Resource Group | tfvars의 `resource_group_name` | Backend용 |
| | Hub | Storage Account | tfvars의 `storage_account_name` | State 저장소 |
| | Hub | Storage Container | tfvars의 `container_name` | State 컨테이너 |
| **Network** | Hub | Resource Group | `test-x-x-rg` | Hub 공통 RG |
| | Hub | Virtual Network | `test-x-x-vnet` | Hub VNet |
| | Hub | Subnet | GatewaySubnet, DNSResolver-Inbound, AzureFirewallSubnet, AzureFirewallManagementSubnet, AppGatewaySubnet, Monitoring-VM-Subnet, pep-snet | 7개 |
| | Hub | VPN Gateway | `test-x-x-vpng` | |
| | Hub | Public IP | `test-x-x-vpng-pip` | VPN Gateway용 |
| | Hub | DNS Private Resolver | `test-x-x-pdr` | |
| | Hub | Private DNS Zone | privatelink.* (blob, file, queue, table, vault, monitor, oms, ods, agentsvc, openai, cognitiveservices, azure-api, ml, notebooks) | 14종, Hub RG |
| | Hub | NSG | test-pep-nsg, test-monitoring-vm-nsg | |
| | Hub | Private DNS Zone VNet Link | test-x-x-vnet-link (Hub VNet ↔ Hub Zones) | |
| | Spoke | Resource Group | `test-x-x-spoke-rg` | Spoke 공통 RG |
| | Spoke | Virtual Network | `test-x-x-spoke-vnet` | Spoke VNet |
| | Spoke | Subnet | apim-snet, pep-snet | 2개 |
| | Spoke | NSG | test-spoke-pep-nsg | |
| | Spoke | Private DNS Zone | privatelink.azure-api.net, openai, cognitiveservices, api.azureml.ms, notebooks | 5종, Spoke RG |
| | Hub | Private DNS Zone VNet Link | test-x-x-spoke-vnet-link (Spoke VNet → Hub Zones, 9종) | blob/vault 등 공유 |
| | Spoke | Private DNS Zone VNet Link | test-x-x-spoke-vnet-link (Spoke VNet → Spoke Zones, 5종) | APIM/OpenAI/AI Foundry |
| | (선택) | keyvault-sg NSG / ASG | keyvault_clients_asg_id 등 | enable_keyvault_sg 시 |
| | (선택) | vm_access_sg ASG | vm_allowed_clients_asg_id | enable_vm_access_sg 시 |
| **Storage** | Hub | Key Vault | `{project_name}-hub-kv` | enable_key_vault 시 |
| | Hub | Storage Account | 모니터링 로그용 (monitoring-storage 모듈) | 여러 개 가능 |
| | Hub | Private Endpoint | Key Vault / Storage용 (pep-snet) | |
| **Compute** | Hub | Linux VM | `test-x-x-monitoring-vm` | Monitoring-VM-Subnet |
| | Hub | Windows VM | `test-x-x-winex` (computer_name 15자 제한으로 짧은 이름 사용) | Monitoring-VM-Subnet |
| | Hub | Managed Identity | Linux Monitoring VM용 (rbac/storage 참조) | |
| **RBAC** | Hub/Spoke | Role Assignment | Monitoring VM / Admin 그룹 등 | compute 배포 후 |
| **Shared-services** | Hub | Log Analytics Workspace | shared-services 모듈 | |
| | Hub | Action Group / Dashboard | | |
| **APIM** | Spoke | API Management | apim-snet 배치 | |
| **AI-services** | Spoke | OpenAI / AI Foundry 등 | Spoke Zone·PE 연동 | |
| **Connectivity** | Hub | VPN Connection 등 | local_gateway 연동 | |

※ 실제 이름은 `terraform.tfvars`의 `project_name`, 각 스택 변수에 따라 달라질 수 있습니다.

### 0.1 스택별 azurerm / AVM 참조

| 스택 | azurerm (Provider) | AVM (Azure Verified Modules) | 비고 |
|------|:------------------:|:----------------------------:|------|
| **network** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(hub-vnet) 내부에서 AVM(Key Vault, Private Endpoint, Log Analytics, Resource Group 등) 사용. |
| **storage** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(monitoring-storage) 내부에서 AVM(Key Vault, Storage, Private Endpoint, Log Analytics 등) 사용. |
| **shared-services** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. log-analytics-workspace(ref=avm-1.0.0)·shared-services Git 모듈 내부에서 AVM(Operational Insights Workspace, Key Vault, Storage 등) 사용. |
| **apim** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(spoke-workloads) 내부에서 AVM(Key Vault, Log Analytics, Resource Group, Private Endpoint 등) 사용. |
| **ai-services** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(spoke-workloads) 내부에서 AVM(Key Vault, Log Analytics, Resource Group, Private Endpoint 등) 사용. |
| **compute** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(linux-monitoring-vm, windows-example 등) 내부에서 AVM(Key Vault, Resource Group, Private Endpoint, Log Analytics 등) 사용. |
| **rbac** | ✅ | — | provider: hashicorp/azurerm. 역할 할당만 관리하여 AVM 모듈 미사용. |
| **connectivity** | ✅ | ✅ (간접) | provider: hashicorp/azurerm. Git 모듈(vnet-peering 등) 내부에서 AVM(Resource Group, Key Vault, Log Analytics, Private Endpoint 등) 사용. |

- **azurerm**: Terraform Azure Provider(`hashicorp/azurerm`) — 모든 스택에서 사용.
- **AVM**: Azure Verified Modules(Registry `Azure/avm-*`) — 공통 Git 모듈(terraform-modules)을 통해 간접 참조. RBAC만 AVM 미참조.

---

## 1. 배포 방식

```bash
cd azure/dev/compute
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 변수, windows_example_admin_password 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

- **선행 스택:** network  
- **다음 스택:** storage → rbac → connectivity  
- rbac·storage는 이 스택 state의 `monitoring_vm_identity_principal_id` output을 참조합니다.

**권한 부여가 어디서 이루어지는지:** 역할 할당(권한 부여)을 **생성하는 스택은 RBAC** 하나입니다. compute는 VM·Identity만 만들고, RBAC 스택이 **이 스택(compute) state의 output**을 `terraform_remote_state`로 읽어서 principal_id 등으로 사용합니다. State는 스택마다 따로 두며, RBAC가 compute(및 network·storage·ai_services) 리소스를 “아는” 방법은 **각 스택 state에 저장된 output만 읽는 것**입니다. 자세한 설명은 **rbac** 스택의 [README](../rbac/README.md) “권한 부여가 이루어지는 방식” 절을 참고하세요.

---

## 2. 배포 과정 상세

### 2.1 명령어 (단계별)

```bash
cd azure/dev/compute
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: hub_subscription_id, backend 변수, windows_example_admin_password, (선택) application_security_group_keys 등
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
# apply 시 "yes" 입력하여 확정
```

### 2.2 배포 시 처리 과정 (로그/데이터 흐름)

`terraform apply` 실행 시 Terraform이 수행하는 흐름을, **구독 ID·VNet ID·시큐리티 그룹(ASG)이 어디서 정해지고 어디에 생성되는지** 중심으로 정리합니다.

| 단계 | 처리 내용 | 참조하는 값 (어디서 오는지) |
|------|-----------|-----------------------------|
| 1. Backend 초기화 | state 저장소 연결. state 키 `azure/dev/compute/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `-var-file=terraform.tfvars`로 변수 값 채움. | `terraform.tfvars` → `variables.tf` |
| 3. **remote_state: network** | `data "terraform_remote_state" "network"` 실행. **Network 스택**의 state 파일을 읽기 전용으로 조회. | backend 설정으로 `azure/dev/network/terraform.tfstate` 참조. **선행 조건:** network 스택이 이미 apply된 상태여야 함. |
| 4. **구독 ID 결정** | VM·NIC는 **Hub 구독**에 생성됨. provider `azurerm.hub`가 사용하는 구독 ID. | `provider.tf`: `var.hub_subscription_id` (terraform.tfvars에서 설정). Spoke VM을 추가할 경우 별도 provider(azurerm.spoke)와 `var.spoke_subscription_id` 사용. |
| 5. **VNet/서브넷 ID 결정** | VM이 생성될 **서브넷**은 Network 스택이 만든 Hub VNet의 서브넷. 서브넷 ID는 compute가 직접 갖지 않고 **network state에서 읽음**. | `main.tf`의 `local.hub_subnet` = `data.terraform_remote_state.network.outputs.hub_subnet_ids["Monitoring-VM-Subnet"]`. 즉 **Network 스택 output**에서 받아 옴. Resource Group 이름도 `local.hub_rg` = `data.terraform_remote_state.network.outputs.hub_resource_group_name`. |
| 6. **시큐리티 그룹(ASG) 할당 흐름** | VM NIC에 붙일 **Application Security Group**은 "Key Vault 접근 허용", "VM 접속 허용" 등 방화벽 정책용. Compute는 ASG ID를 **직접 입력하지 않고**, **키 이름**만 지정하면 Network state에서 ID를 가져옴. | `main.tf`의 `local.asg_id_by_key`: `"keyvault_clients"` → `data.terraform_remote_state.network.outputs.keyvault_clients_asg_id`, `"vm_allowed_clients"` → `data.terraform_remote_state.network.outputs.vm_allowed_clients_asg_id`. `var.application_security_group_keys`(기본값 `["keyvault_clients","vm_allowed_clients"]`) 또는 VM별 `var.linux_monitoring_vm_application_security_group_keys`가 이 키 목록. Terraform이 키 목록을 ID 목록으로 바꾼 뒤 각 VM 모듈에 `application_security_group_ids`로 전달. |
| 7. VM 모듈 호출 | `module "linux_monitoring_vm"`, `module "windows_example"` 등. 각 모듈은 **subnet_id**(위에서 받은 Hub 서브넷 ID), **resource_group_name**(Hub RG), **application_security_group_ids**(위에서 해석한 ASG ID 목록) 등을 인자로 받음. | `local.hub_rg`, `local.hub_subnet`, `local.asg_id_by_key`로부터 만든 ID 목록, 및 `var.*` (vm_name, vm_size 등). |
| 8. 하위 모듈(linux-monitoring-vm 등) | NIC 생성 후 `azurerm_network_interface_application_security_group_association`으로 **NIC에 ASG 연결**. 시큐리티 그룹은 Network 스택에서 만든 리소스이지만, **동일 테넌트**이므로 Hub 구독의 ASG를 이 VM의 NIC(Hub 구독)에 붙임. | 모듈 인자로 받은 `application_security_group_ids`(이미 ID 목록으로 변환됨). |
| 9. Output 기록 | `monitoring_vm_identity_principal_id`, `linux_monitoring_vm_id` 등이 state에 기록됨. RBAC·storage 스택이 remote_state로 이 값을 읽음. | `outputs.tf` |

**정리:**  
- **구독 ID:** `terraform.tfvars`의 `hub_subscription_id` → `provider.tf`의 `azurerm.hub`에 연결. VM은 Hub 구독에 생성됨.  
- **VNet/서브넷 ID:** Compute는 VNet을 만들지 않음. **Network 스택 state**의 `hub_subnet_ids["Monitoring-VM-Subnet"]`, `hub_resource_group_name`을 remote_state로 읽어서, **그 서브넷·RG에** VM을 생성함.  
- **시큐리티 그룹(ASG):** Network 스택에서 `enable_pe_inbound_from_asg`·`enable_vm_access_sg` 등으로 만든 ASG의 **ID**를, Compute는 **키**(`keyvault_clients`, `vm_allowed_clients`)만 tfvars에 두고, main.tf의 `local.asg_id_by_key`와 remote_state로 **ID로 변환**한 뒤 각 VM NIC에 할당함.

### 2.3 terraform apply 시 파일 참조 순서

1. **backend.hcl** (init 시) — state 저장소.
2. **provider.tf** — 구독 ID(`var.hub_subscription_id` 등) 사용.
3. **variables.tf** — 변수 정의.
4. **terraform.tfvars** — 변수 값 (project_name, hub_subscription_id, application_security_group_keys, linux_monitoring_vm_* 등).
5. **main.tf** — **data "terraform_remote_state" "network"** 가 가장 먼저 실행되어 Network state 조회. 이후 **locals**(hub_rg, hub_subnet, asg_id_by_key) 계산. 그 다음 **module "linux_monitoring_vm"**, **module "windows_example"** 호출 시 위 locals와 var, asg_id_by_key로 만든 application_security_group_ids 전달.
6. **./linux-monitoring-vm/** — `source = "./linux-monitoring-vm"`. 내부에서 `module "vm"`(Git virtual-machine) 호출 후 `azurerm_network_interface_application_security_group_association`으로 ASG 연결.
7. **./windows-example/** — 동일 패턴.
8. **outputs.tf** — output 값 state에 기록.

**의존성 요약:** main.tf → (remote_state로 network state 읽음) → network의 outputs 사용 → locals·모듈 인자 계산 → 하위 디렉터리(./linux-monitoring-vm 등) 참조. 따라서 **network 스택이 먼저 apply되어 있어야** compute의 plan/apply가 정상 동작합니다.

---

## 3. 추가 가이드 (신규 VM 추가)

**공통 절차 (신규 인스턴스 추가 시)**  
(1) 예시 디렉터리 복사 → (2) 필요 시 새 디렉터리 내 기본값 수정 → (3) 루트 `main.tf`에 module 블록 추가 → (4) 루트 `variables.tf`에 변수 추가 → (5) `terraform.tfvars`에 값 설정 → (6) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`.

---

### 신규 서버 생성 시 Network 스택 방화벽 정책(ASG) 반영 절차

Compute에서는 **ASG ID를 직접 조회·입력하지 않고**, **변수명(키)** 만 지정하면 됩니다. Network 스택 state에서 키에 해당하는 ASG ID를 자동으로 가져옵니다.

1. **Network 스택 먼저 적용**  
   `azure/dev/network`에서 `enable_keyvault_sg`·`enable_pe_inbound_from_asg`·`enable_vm_access_sg` 등 원하는 방화벽 정책을 켠 뒤 `terraform apply`까지 완료합니다.

2. **Compute에서 사용하는 키**  
   - `keyvault_clients` → Key Vault 접근 허용 (PE 인바운드 정책)  
   - `vm_allowed_clients` → VM 접속 허용 (타겟 VM NSG 인바운드 정책)  
   루트 변수 `application_security_group_keys` 기본값이 `["keyvault_clients", "vm_allowed_clients"]`이므로 **tfvars에 아무것도 넣지 않으면** 모든 VM에 두 정책이 적용됩니다. ID 조회 불필요.

3. **신규 VM 추가 시**  
   - 예시 디렉터리 복사 → 루트 `main.tf`에  
     `application_security_group_ids = [for k in coalesce(var.새이름_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]`  
     로 모듈 인자 추가.  
   - 루트 `variables.tf`에  
     `variable "새이름_application_security_group_keys" { type = list(string), default = null }`  
     추가.  
   - `terraform.tfvars`는 비워 두면 전역 `application_security_group_keys`가 적용됩니다. VM별로 다르게 하려면 `새이름_application_security_group_keys = ["keyvault_clients"]` 처럼 **키만** 지정하면 됩니다.

4. **배포**  
   `terraform plan` → `apply`  
   → 키가 Network output과 매핑되어 ID로 해석되고, 해당 VM NIC에 ASG가 연결됩니다.

**요약:**  
ID는 넣지 않고 **키(`keyvault_clients`, `vm_allowed_clients`)만** 사용합니다. 전역 기본값으로 두 키가 모두 적용되므로, 인간 개입 없이 신규 VM에도 Network에 등록된 방화벽 정책이 자동 반영됩니다.

---

새 Linux 서버를 추가할 때:

1. **디렉터리 복사**  
   `linux-monitoring-vm` 디렉터리를 복사해 새 이름 생성 (예: `linux-app-01`).

2. **(선택) 새 디렉터리 기본값 수정**  
   `linux-app-01/variables.tf`에서 `vm_size`, `vm_extensions` 등 필요 시 수정.  
   공통 모듈(terraform-modules)에 옵션이 없으면 해당 레포 반영 후 이쪽에서 변수로 전달.

3. **루트 main.tf에 module 블록 추가**  
   `application_security_group_ids = [for k in coalesce(var.linux_app_01_application_security_group_keys, var.application_security_group_keys) : local.asg_id_by_key[k] if try(local.asg_id_by_key[k], null) != null]` 를 모듈 인자에 넣기 (기존 `linux_monitoring_vm` 블록 참고).  
   **키만** 사용하므로 ASG ID 조회 불필요.

4. **루트 variables.tf에 변수 추가**  
   `linux_app_01_vm_name`, `linux_app_01_vm_size`, `linux_app_01_ssh_key_filename`, `linux_app_01_application_security_group_keys`(기본값 `null`) 등 정의.

5. **terraform.tfvars에 값 설정**  
   위 변수에 맞게 값 입력.

6. **배포**  
   `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`.

Windows VM 추가 시에는 `windows-example` 디렉터리를 복사한 뒤 동일하게 루트에 module·변수·tfvars를 추가합니다.

---

## 4. 변경 가이드 (기존 리소스 수정)

- **VM 크기·사용자명·확장 등**  
  `terraform.tfvars`에서 해당 VM용 변수(`linux_monitoring_vm_size`, `windows_example_admin_password` 등) 수정 후  
  `terraform plan -var-file=terraform.tfvars`로 변경 내용 확인 → `terraform apply -var-file=terraform.tfvars`로 적용.

- **하위 모듈 내부 로직 변경**  
  해당 하위 디렉터리(예: `linux-monitoring-vm/main.tf`) 또는 공통 모듈(terraform-modules) 수정 후,  
  루트에서 `terraform init -upgrade`(필요 시) → `plan` → `apply`.

- VM 관련 변경은 plan에서 **replace**가 나올 수 있으므로, plan 결과를 반드시 확인한 뒤 적용합니다.

---

## 5. 삭제 가이드 (리소스 제거)

- **특정 VM만 제거**  
  1. 루트 `main.tf`에서 해당 VM의 `module "xxx" { ... }` 블록 전체 삭제(또는 `enable_vm = false` 등으로 비활성화).  
  2. `variables.tf`·`terraform.tfvars`에서 해당 VM용 변수 제거 또는 주석 처리.  
  3. `outputs.tf`에서 해당 VM 관련 output 제거(있을 경우).  
  4. `terraform plan -var-file=terraform.tfvars`로 destroy 대상 확인 후 `terraform apply -var-file=terraform.tfvars`로 적용.  
  5. (선택) 물리 디렉터리(예: `linux-app-01`) 삭제.

- **Linux Monitoring VM 제거 시**  
  rbac·storage가 이 VM의 `monitoring_vm_identity_principal_id`를 참조하므로, 제거 전에 rbac/storage 쪽 의존성을 정리하거나 대체 Identity를 지정해야 할 수 있습니다.

- **state에서만 제거하고 Azure 리소스는 유지**  
  `terraform state rm 'module.xxx'` 사용 (신중히 진행).

---

## 6. 디렉터리 구성

| 디렉터리 | 역할 |
|----------|------|
| **compute/** (루트) | main.tf, variables.tf, outputs.tf, backend.tf, provider.tf. 여기서만 plan/apply. |
| **linux-monitoring-vm/** | Linux VM 모듈 (rbac/storage가 이 VM Identity 참조) |
| **windows-example/** | Windows VM 모듈 |
| **(신규)** | 위 예시 디렉터리 복사 후 루트에 module·변수 추가 |

---

## 부록: 스택별 README 메뉴얼 점검 기준

각 스택 README는 아래 항목이 있으면 메뉴얼이 갖춰진 것으로 봅니다. (compute README 구조를 기준으로 함.)

| 항목 | network | storage | shared-services | apim | ai-services | compute | rbac | connectivity |
|------|:-------:|:-------:|:---------------:|:----:|:-----------:|:-------:|:----:|:------------:|
| 1. 배포 방식 (명령어·선행/다음 스택) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2.1 명령어 단계별 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2.2 배포 시 처리 과정 (표) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 2.3 파일 참조 순서 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 3. 추가 가이드 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 4. 변경 가이드 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 5. 삭제 가이드 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| 6. 디렉터리/하위 모듈 또는 참고 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

- **compute**만 **0. 전체 배포 리소스 일람** 표 포함 (선택).
- **docs/** 링크는 로컬 문서 참고로 안내 (원격 저장소에서는 docs 제외).
