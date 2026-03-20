# Compute

compute 스택은 **이 디렉터리(루트)**에서만 `terraform plan` / `apply`를 실행합니다.  
State 1개(`azure/dev/06.compute/terraform.tfstate`), 하위 디렉터리(linux-monitoring-vm, windows-example 등)는 **모듈**로만 호출합니다.

**변수 관리 방식:**  
- **루트**: 구독 ID, backend, location, tags, 방화벽(ASG) 키, Windows VM 비밀번호 등 **공통·컨텍스트·보안**만 관리.  
- **하위 폴더**: 각 VM의 **리소스 정보**(이름 접미사, 사이즈, OS, 확장 등)는 **해당 폴더의 variables.tf 기본값**에서 관리.  
→ 폴더를 복제한 뒤 **그 폴더의 variables.tf만 수정**하면 되고, 루트에는 module 블록(과 Windows인 경우 비밀번호 변수 1개)만 추가하면 됩니다.

---

## 파일·디렉터리 역할 및 배포 시 수정 위치

### 스택 루트 파일

| 파일 | 역할 | 주로 수정하는 내용 |
|------|------|-------------------|
| `main.tf` | remote_state(network), `module` 호출(Linux/Windows VM), `locals`(ASG ID 매핑) | VM 모듈 추가·NIC·ASG 연결 |
| `variables.tf` | 루트 변수 | `application_security_group_keys`, Windows용 `*_admin_password` 변수 등 |
| `terraform.tfvars` | 실제 값 | `hub_subscription_id`, `spoke_subscription_id`(Spoke VM 시), `backend_*`, `windows_example_admin_password`, `application_security_group_keys` |
| `backend.tf` / `backend.hcl` | 원격 state | Bootstrap 연동 |
| `provider.tf` | Hub(및 필요 시 Spoke) 구독 | VM이 올라갈 구독 |
| `outputs.tf` | `monitoring_vm_identity_principal_id` 등 | storage·rbac가 참조 |

### 하위 디렉터리(VM 모듈)

| 디렉터리 | 역할 | 신규 VM 시 |
|----------|------|------------|
| `linux-monitoring-vm/`, `windows-example/` | Git `virtual-machine` 래퍼 + NIC·ASG 연결 | **폴더 복사 후 해당 `variables.tf`만** 수정. 자세한 변수 의미는 각 폴더 `README.md` 참고 |
| (신규) `linux-app-01/` 등 | 동일 패턴 | `vm_name_suffix`, `vm_size` 등은 **복사한 폴더 `variables.tf` 기본값** |

### 신규 VM 추가 시 변수(의미) 요약

| 구분 | 어디서 수정 | 의미 |
|------|-------------|------|
| **Linux** | 새 폴더 `variables.tf` | `vm_name_suffix`: 이름 접미사. `vm_size`: SKU. `admin_username`, `ssh_private_key_filename`, `vm_extensions` |
| **Windows** | 새 폴더 `variables.tf` + 루트 | 폴더: `vm_name_suffix`, `vm_computer_name_suffix`(OS 호스트명 15자 제한). 루트: **해당 VM용 `admin_password` 변수 1개**만 추가 |
| **ASG** | 루트 `terraform.tfvars` | `application_security_group_keys`: Network output에 매핑할 ASG 키 목록(`keyvault_clients`, `vm_allowed_clients`) |

---

## 0. 복사/붙여넣기용 배포 명령어 (처음 배포 시)

프로젝트 루트에서 시작한다고 가정합니다. **선행:** network 스택 apply 완료.

**1단계: 변수 파일 복사**
```bash
cd azure/dev/06.compute
cp terraform.tfvars.example terraform.tfvars
```

**2단계: terraform.tfvars 수정**  
- `hub_subscription_id`, `spoke_subscription_id`, `backend_*` (Bootstrap과 동일)  
- `windows_example_admin_password` → 반드시 강한 비밀번호로 변경  
- (선택) `application_security_group_keys`  
- **VM별 이름·사이즈 등은 수정하지 않음** → 각 하위 폴더(linux-monitoring-vm, windows-example)의 **variables.tf 기본값**에서 관리

**3단계: init / plan / apply (한 블록 통째로 복사 후 실행)**
```bash
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
apply 시 `yes` 입력.

---

## 0-2. 전체 배포 리소스 일람 (스택별)

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

---

## 1. 배포 방식

```bash
cd azure/dev/06.compute
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
cd azure/dev/06.compute
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
| 1. Backend 초기화 | state 저장소 연결. state 키 `azure/dev/06.compute/terraform.tfstate`. | `backend.hcl` |
| 2. 변수 로드 | `-var-file=terraform.tfvars`로 변수 값 채움. | `terraform.tfvars` → `variables.tf` |
| 3. **remote_state: network** | `data "terraform_remote_state" "network"` 실행. **Network 스택**의 state 파일을 읽기 전용으로 조회. | backend 설정으로 `azure/dev/01.network/terraform.tfstate` 참조. **선행 조건:** network 스택이 이미 apply된 상태여야 함. |
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
(1) 예시 디렉터리 복사(예: linux-monitoring-vm → linux-app-01) → (2) **복사한 폴더의 variables.tf**에서 `vm_name_suffix`, `vm_size`, `admin_username`, `vm_extensions` 등 기본값 수정 → (3) 루트 `main.tf`에 module 블록만 추가(컨텍스트만 전달) → (4) Windows인 경우 루트 `variables.tf`·`terraform.tfvars`에 해당 VM용 `admin_password` 1개 추가 → (5) **이 스택 루트에서** `terraform plan -var-file=terraform.tfvars` → `apply`.

**복사 후 수정 가이드:**  
- **Linux VM:** 폴더 복제(예: linux-monitoring-vm → linux-app-01) 후 **해당 폴더의 variables.tf**에서 `vm_name_suffix`, `vm_size`, `admin_username`, `vm_extensions` 등 기본값만 수정. 루트 main.tf에 module 블록만 추가(VM별 변수 없음).  
- **Windows VM:** 동일. 폴더 variables.tf 기본값 수정 + 루트 main.tf에 module 블록 + 루트에 해당 VM용 `admin_password` 변수 1개만 추가.

---

### 신규 서버 생성 시 Network 스택 방화벽 정책(ASG) 반영 절차

Compute에서는 **ASG ID를 직접 조회·입력하지 않고**, **변수명(키)** 만 지정하면 됩니다. Network 스택 state에서 키에 해당하는 ASG ID를 자동으로 가져옵니다.

1. **Network 스택 먼저 적용**  
   `azure/dev/01.network`에서 `enable_keyvault_sg`·`enable_pe_inbound_from_asg`·`enable_vm_access_sg` 등 원하는 방화벽 정책을 켠 뒤 `terraform apply`까지 완료합니다.

2. **Compute에서 사용하는 키**  
   - `keyvault_clients` → Key Vault 접근 허용 (PE 인바운드 정책)  
   - `vm_allowed_clients` → VM 접속 허용 (타겟 VM NSG 인바운드 정책)  
   루트 변수 `application_security_group_keys` 기본값이 `["keyvault_clients", "vm_allowed_clients"]`이므로 **tfvars에 아무것도 넣지 않으면** 모든 VM에 두 정책이 적용됩니다. ID 조회 불필요.

3. **신규 VM 추가 시**  
   - 루트 `main.tf`의 module 블록에서는 `application_security_group_ids = local.asg_ids` 로 **동일한 목록**을 넘깁니다. 루트 `application_security_group_keys`가 모든 VM에 공통 적용되므로, VM별 변수 추가 없이 새 VM에도 자동 반영됩니다.

4. **배포**  
   `terraform plan` → `apply`  
   → 키가 Network output과 매핑되어 ID로 해석되고, 해당 VM NIC에 ASG가 연결됩니다.

**요약:**  
ID는 넣지 않고 **키(`keyvault_clients`, `vm_allowed_clients`)만** 사용합니다. 전역 기본값으로 두 키가 모두 적용되므로, 인간 개입 없이 신규 VM에도 Network에 등록된 방화벽 정책이 자동 반영됩니다.

---

### 메뉴얼: Windows VM에서 Key Vault(Private Endpoint) 접근 — ASG·네트워크·권한

Private Endpoint가 **Hub `pep-snet`**에 있는 Key Vault에, **Windows VM(Monitoring-VM-Subnet 등)**에서 HTTPS(443)로 접근하려면 **네트워크(NSG+ASG)** 와 **Key Vault 권한(RBAC)** 이 둘 다 필요합니다.

#### 동작 개념

| 구분 | 역할 |
|------|------|
| **NSG** | 서브넷(예: `pep-snet`)에 연결. PE로 들어오는 트래픽에 대해 인바운드 허용/차단. |
| **ASG** | `keyvault_clients` ASG에 **Windows NIC을 멤버로 등록**하면, PE NSG 규칙에서 **소스 = 이 ASG, 포트 443** 한 줄로 허용할 수 있음. |
| **RBAC** | NSG는 통과만 시킴. 비밀/키 읽기는 Azure **역할**(예: Key Vault Secrets User)이 있어야 함. |

#### 전제 조건

- **Storage** 스택: Hub에 Key Vault + **Private Endpoint**가 `pep-snet`(또는 설계상 PE 서브넷)에 생성되어 있음.  
- **Network** 스택: 동일 Hub VNet에 `pep-snet`·해당 NSG가 있음.  
- 상세 네트워크 설계는 [`../01.network/README.md`](../01.network/README.md) **시나리오 3: keyvault-sg** 참고.

#### 1단계 — Network 스택 (`azure/dev/01.network/terraform.tfvars`)

Key Vault PE 쪽 **인바운드(소스 ASG, 443)** 와 `keyvault_clients` ASG를 켭니다.

```hcl
enable_keyvault_sg         = true
enable_pe_inbound_from_asg = true
# 선택: keyvault_clients_asg_name = "keyvault-clients-asg"
# 선택: 클라이언트 서브넷 NSG에 KV 아웃바운드 규칙을 추가하려면 (예시)
# hub_nsg_keys_add_keyvault_rule = ["monitoring_vm"]
```

`azure/dev/01.network`에서 `terraform plan` → `apply` 후, state에 **`keyvault_clients_asg_id`** output이 생겨야 합니다.

#### 2단계 — Storage 스택

Key Vault·PE가 아직 없으면 **`azure/dev/02.storage`** 를 먼저 배포합니다(모니터링 Storage 모듈이 KV·PE를 만드는 구조).

#### 3단계 — Compute 스택 (이 스택)

Windows VM NIC에 위 ASG를 붙입니다. **ASG 리소스 ID를 직접 쓰지 않고**, 루트 변수 **키 목록**만 지정합니다.

`terraform.tfvars`:

```hcl
# 기본값과 동일하면 생략 가능
application_security_group_keys = ["keyvault_clients", "vm_allowed_clients"]
```

- `main.tf`의 `local.asg_id_by_key["keyvault_clients"]` ← network output `keyvault_clients_asg_id`  
- `module "windows_example"` 등에 `application_security_group_ids = local.asg_ids` 로 전달되고, 하위 모듈에서 **NIC ↔ ASG** 연결(`azurerm_network_interface_application_security_group_association`)이 생성됩니다.

**순서:** Network apply로 ASG·NSG 규칙이 생긴 뒤 Compute apply(또는 한 번에 apply해도 되나, network state에 output이 있어야 compute plan이 유효함).

#### 4단계 — 권한(RBAC)

- **네트워크만 맞고 403**이 나오면 RBAC 문제입니다.  
- VM에 **Managed Identity**를 쓰는 경우: **`azure/dev/07.rbac`** 에서 해당 MI에 Key Vault 범위 **Secrets User** 등 역할 부여(스택 README·`terraform.tfvars.example` 참고).  
- **사용자/앱 ID**로 SDK/포털 접근 시: 동일하게 해당 principal에 KV 데이터 플레인 역할 부여.  
- RBAC 스택은 compute·storage·network state의 output을 읽어 `azurerm_role_assignment`을 만듭니다. 자세한 흐름은 [`../07.rbac/README.md`](../07.rbac/README.md) 를 참고합니다.

#### 배포 순서 요약

`01.network`(시나리오 3) → `02.storage`(KV+PE) → **`06.compute`(Windows, ASG 키)** → `07.rbac`(필요 시 KV 역할)

---

**새 Linux 서버를 추가할 때**

1. **디렉터리 복사**  
   `linux-monitoring-vm` 을 복사해 새 이름 생성 (예: `linux-app-01`).

2. **복사한 폴더에서만 수정**  
   `linux-app-01/variables.tf` 에서 **기본값**만 수정: `vm_name_suffix`(예: `"app-01"`), `vm_size`, `admin_username`, `ssh_private_key_filename`, `vm_extensions` 등.

3. **루트 main.tf에 module 블록만 추가**  
   기존 `linux_monitoring_vm` 블록을 복사해 `module "linux_app_01"` 로 바꾸고, `source = "./linux-app-01"` 로 지정. 전달 인자는 동일(name_prefix, resource_group_name, subnet_id, location, tags, application_security_group_ids = local.asg_ids). **루트 variables.tf / terraform.tfvars 에 VM별 변수 추가 없음.**

4. **배포**  
   `terraform plan -var-file=terraform.tfvars` → `terraform apply -var-file=terraform.tfvars`.

**Windows VM 추가 시**  
위와 동일하게 폴더 복사 → 해당 폴더 variables.tf 기본값 수정 → 루트 main.tf에 module 블록 추가.  
추가로 **루트 variables.tf**에 해당 VM용 `admin_password` 변수 1개, **terraform.tfvars**에 비밀번호 값만 넣습니다. (보안상 비밀번호만 루트에서 관리.)

---

## 4. 변경 가이드 (기존 리소스 수정)

- **VM 크기·이름 접미사·사용자명·확장 등**  
  **해당 VM 폴더의 variables.tf** 기본값을 수정한 뒤, 루트에서 `terraform plan -var-file=terraform.tfvars` → `apply`.  
  **Windows 비밀번호만** 루트 `terraform.tfvars`에서 수정.

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
