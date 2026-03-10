# Compute 배포 가이드

Monitoring VM(Linux, SSH 키 인증, Azure Monitor Linux Agent)을 Hub의 Monitoring-VM-Subnet에 배포하는 스택입니다. **선행 스택:** ai-services. **다음 스택:** rbac.  
※ 역할 할당(RBAC)은 **rbac** 스택에서 관리합니다.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/compute
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `location`, `tags` | 공통 식별자·리전·태그 | 프로젝트 규칙 (예: `test`, `dev`, `Korea Central`) |
| `hub_subscription_id`, `spoke_subscription_id` | Hub/Spoke 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `vm_size` | VM SKU | 예: `Standard_B2s`. [Azure VM 크기](https://learn.microsoft.com/azure/virtual-machines/sizes) 참고. |
| `vm_admin_username` | OS 로그인 사용자명 | 예: `azureadmin`. SSH 접속 시 사용. |
| `enable_monitoring_vm` | Monitoring VM 생성 여부 | `true`면 VM·NIC·확장·Managed Identity 생성. `false`면 미생성. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/compute
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

VM 이름은 locals에서 `project_name` 등으로 생성. SSH 키는 Terraform이 생성하며 개인키는 로컬 파일로 저장됩니다.

| 구분 | 리소스 종류 | 개수 | Azure 리소스 네이밍 / 비고 |
|------|-------------|------|----------------------------|
| TLS Private Key | VM SSH 키 쌍 | 1 | (로컬, state에 저장) |
| Local File | 개인키 파일 | 1 | `var.vm_ssh_private_key_filename` (예: monitoring_vm_key.pem). **절대 커밋 금지.** |
| Network Interface | VM NIC | 1 | virtual-machine 모듈 내부 네이밍 |
| OS Disk / VM | Linux VM | 1 | `{project_name}-x-x-vm` (예: test-x-x-vm). Monitoring-VM-Subnet, Managed Identity 포함. |
| VM Extension | Azure Monitor Linux Agent | 1 | VM에 연결. |

※ VNet/서브넷은 **network** 스택, 역할 할당은 **rbac** 스택에서 관리합니다.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: VM 확장 1개 추가)

1. **virtual-machine 모듈**이 해당 확장을 인자로 받으면: 스택에서 `vm_extensions`에 항목 추가 후 plan/apply.  
2. **모듈에 없는 확장/리소스:** **3.4**에 따라 terraform-modules 레포의 virtual-machine 모듈에 옵션 추가 후 push → 이 스택에서 `terraform init -backend-config=backend.hcl -upgrade` → plan → apply.

### 3.2 기존 리소스 변경 (예: VM 사이즈 변경)

1. **VM 사이즈 변경:** `terraform.tfvars`에서 `vm_size` 수정 (예: `Standard_B2s` → `Standard_B4ms`).  
2. `terraform plan -var-file=terraform.tfvars`로 **in-place update** 또는 **replace** 여부 확인.  
3. `terraform apply -var-file=terraform.tfvars`로 적용. (VM 크기 변경은 대부분 재부팅으로 적용됨.)  
4. **관리 사용자명·SSH 키 교체:** 변수 변경 후 apply 시 VM이 재생성될 수 있으므로 plan 결과를 반드시 확인합니다.

### 3.3 기존 리소스 삭제

1. VM 제거: `enable_monitoring_vm = false`로 변경하거나, 모듈 호출을 제거(또는 count=0).  
2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.  
3. **주의:** VM 삭제 시 생성된 SSH 개인키 파일(예: monitoring_vm_key.pem)은 로컬에 남습니다. 필요 시 수동 삭제.  
4. state만 제거: `terraform state rm '주소'` (Azure 리소스는 별도 삭제).

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

1. **terraform-modules** 레포에서 **virtual-machine** (또는 해당 모듈) 수정 후 커밋·push.  
2. **이 스택(compute)에서:**  
   - `terraform init -backend-config=backend.hcl -upgrade`  
   - `terraform plan -var-file=terraform.tfvars`  
   - `terraform apply -var-file=terraform.tfvars`  
3. 모듈 소스가 `ref=main`이면 `-upgrade` 시 최신 main을 사용합니다.
