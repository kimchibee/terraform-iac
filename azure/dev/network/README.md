# Network 배포 가이드

Hub VNet, Spoke VNet, 서브넷, VPN Gateway, Private DNS Resolver, NSG 등을 관리하는 스택입니다. **선행 스택:** Bootstrap. **다음 스택:** storage.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/network
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `location`, `tags` | 공통 식별자·리전·태그 | 프로젝트 규칙. 예: `test`, `dev`, `Korea Central` |
| `hub_subscription_id` | Hub 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `spoke_subscription_id` | Spoke 구독 ID | 동일하게 Portal 또는 `az account list -o table` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` (예: `terraform-state-rg`) |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `hub_vnet_address_space`, `hub_subnets` | Hub VNet·서브넷 정의 | 예시는 `terraform.tfvars.example` 참고. 주소 공간·서브넷 목록은 설계 문서 또는 예시 그대로 사용 후 필요 시 수정. |
| `spoke_vnet_address_space`, `spoke_subnets` | Spoke VNet·서브넷 정의 | 동일. `apim-snet`, `pep-snet` 등 예시 참고. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/network
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

네이밍: `locals.name_prefix = "${var.project_name}-x-x"` (예: `test-x-x`). 아래는 그 접두사 기준입니다.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| Resource Group | Hub RG | 1 | `{project_name}-x-x-rg` |
| Virtual Network | Hub VNet | 1 | `{project_name}-x-x-vnet`. 주소 공간: `var.hub_vnet_address_space` |
| Subnet | Hub 서브넷 | 7 | GatewaySubnet, DNSResolver-Inbound, AzureFirewallSubnet, AzureFirewallManagementSubnet, AppGatewaySubnet, Monitoring-VM-Subnet, pep-snet. 이름은 `hub_subnets` 키 그대로. |
| NSG | Monitoring VM | 1 | `{project_name}-monitoring-vm-nsg` |
| NSG | Hub pep | 1 | `{project_name}-pep-nsg` |
| Resource Group | Spoke RG | 1 | `{project_name}-x-x-spoke-rg` |
| Virtual Network | Spoke VNet | 1 | `{project_name}-x-x-spoke-vnet` |
| Subnet | Spoke 서브넷 | 2 | apim-snet, pep-snet |
| NSG | Spoke pep | 1 | `{project_name}-spoke-pep-nsg` |
| VPN Gateway | 공용 IP / Gateway / Local GW / Connection | 1세트 | `{project_name}-x-x-vpng` 등. `local_gateway_configs` 설정 시에만 연결 생성. |
| Private DNS Resolver | Resolver / Inbound Endpoint | 1 | `{project_name}-x-x-pdr` |
| Private DNS Zone | Zone + Hub 링크 | 다수 | `privatelink.*` 등. Zone 이름은 모듈 내 정의. |
| Private DNS Zone | Spoke 링크 | 다수 | `{spoke_vnet_name}-link` |

※ Peering은 **connectivity** 스택에서 생성합니다.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: 서브넷 1개 추가)

1. `terraform.tfvars`의 `hub_subnets` 또는 `spoke_subnets`에 새 키와 `address_prefixes` 등 객체를 추가합니다.  
2. **hub-vnet / spoke-vnet 모듈**이 해당 키를 그대로 서브넷 이름으로 사용하므로, `locals`의 `hub_subnet_names` / `spoke_subnet_names`에 새 이름을 추가해야 합니다. (`network/locals.tf` 수정)  
3. `terraform plan` → `apply`로 반영합니다.  
4. **모듈에 없는 리소스 타입**(예: 새 종류의 Gateway)이 필요하면 **3.4**에 따라 terraform-modules 레포에 템플릿을 추가한 뒤, 이 스택에서 `init -upgrade` → plan → apply 합니다.

### 3.2 기존 리소스 변경 (예: VNet 주소 공간, 서브넷 CIDR, VPN SKU)

1. `terraform.tfvars` 또는 `variables.tf` 기본값에서 해당 변수를 수정합니다.  
2. `terraform plan -var-file=terraform.tfvars`로 변경 내용 확인 후 `terraform apply -var-file=terraform.tfvars`로 적용합니다.  
3. 모듈 인자만 바꾸는 경우: 모듈이 해당 인자를 지원하면 그대로 적용. 지원하지 않으면 **3.4**에 따라 모듈 레포 수정 후 `init -upgrade` → plan → apply 합니다.

### 3.3 기존 리소스 삭제

1. 제거할 서브넷: `hub_subnets` / `spoke_subnets`에서 해당 키를 제거하고, `locals`의 `*_subnet_names`에서도 제거합니다.  
2. 리소스 블록을 직접 제거하는 경우: `main.tf` 또는 모듈 호출에서 제거(또는 주석 처리) 후 `terraform plan`으로 destroy 대상 확인 → `apply`로 삭제합니다.  
3. state에서만 제거: `terraform state rm '주소'` (Azure 리소스는 수동 삭제).

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

**상황:** 신규 리소스(또는 옵션)가 필요한데, hub-vnet / spoke-vnet 등 공통 모듈에 해당 템플릿이 없음.

1. **terraform-modules 레포에서 작업**  
   - 해당 모듈 디렉터리에서 리소스/변수 추가 또는 수정 후, 테스트용 `terraform plan`으로 확인합니다.  
   - 변경 사항을 커밋하고 원격(예: `main`)에 push합니다.

2. **이 스택(network)에서 반드시 수행할 순서**  
   - **업그레이드:** `terraform init -backend-config=backend.hcl -upgrade`  
   - **플랜:** `terraform plan -var-file=terraform.tfvars`  
   - **배포:** `terraform apply -var-file=terraform.tfvars`

3. 모듈 소스가 `git::...?ref=main`이면 `init -upgrade` 시 최신 `main`을 가져옵니다. 태그/브랜치를 쓰는 경우 해당 ref를 push한 뒤 동일한 순서(upgrade → plan → apply)를 따릅니다.
