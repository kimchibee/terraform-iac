# RBAC 배포 가이드

Monitoring VM(compute 스택)의 Managed Identity에 Hub/Spoke 리소스 접근용 역할만 부여하는 스택입니다. **선행 스택:** compute. **다음 스택:** connectivity.  
※ VM·VNet·Storage·APIM 등 인프라 리소스는 **생성하지 않고**, **역할 할당만** 관리합니다.

---

## 1. 배포명령 가이드

### a. 변수 파일 준비

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/rbac
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars를 편집하여 아래 필수 항목을 채웁니다.
```

### b. terraform.tfvars에서 필수로 작성해야 할 내용

| 변수명 | 설명 | 작성에 필요한 정보 / 출처 |
|--------|------|----------------------------|
| `project_name`, `environment`, `tags` | 공통 식별자·태그 | 프로젝트 규칙 (예: `test`, `dev`) |
| `hub_subscription_id`, `spoke_subscription_id` | Hub/Spoke 구독 ID | Azure Portal → **구독** → 구독 ID. 또는 `az account show --query id -o tsv` |
| `backend_resource_group_name` | Backend RG 이름 | **Bootstrap** `terraform.tfvars`의 `resource_group_name` |
| `backend_storage_account_name` | Backend 스토리지 계정 이름 | Bootstrap의 `storage_account_name` |
| `backend_container_name` | Backend 컨테이너 이름 | Bootstrap의 `container_name` (기본 `tfstate`) |
| `enable_monitoring_vm_roles` | VM에 역할 부여 여부 | compute 스택에서 VM 사용 시 `true`. false면 역할 할당 리소스 미생성. |
| `enable_key_vault_roles` | Key Vault 관련 역할 부여 여부 | storage 스택에서 Key Vault 사용 시 `true`. |

### c. 배포 실행 순서

```bash
cd /Users/chi-sungkim/azure_ai/terraform-iac/azure/dev/rbac
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

## 2. 현 스택에서 다루는 리소스

이 스택은 **Azure 리소스(RG, VM, Storage 등)를 만들지 않고**, **역할 할당(Role Assignment)** 만 생성합니다. 대상 리소스 ID는 **remote_state**로 compute, network, storage, ai_services에서 읽습니다.

| 구분 | 리소스 종류 | 개수 | 대상(Scope) / 역할 이름 |
|------|-------------|------|--------------------------|
| Role Assignment | VM → Monitoring Storage 계정들 | for_each (계정당 1) | Scope: storage 스택의 각 monitoring_storage_account_id. 역할: **Storage Blob Data Contributor** |
| Role Assignment | VM → Hub Key Vault | 0 또는 2 | Scope: storage 스택 key_vault_id. 역할: **Key Vault Secrets User**, **Key Vault Reader** |
| Role Assignment | VM → Hub RG | 0 또는 1 | Scope: network 스택 hub_resource_group_id. 역할: **Reader** |
| Role Assignment | VM → Spoke Key Vault | 0 또는 1 | Scope: ai_services 스택 key_vault_id. 역할: **Key Vault Secrets User** |
| Role Assignment | VM → Spoke Storage | 0 또는 1 | Scope: ai_services 스택 storage_account_id. 역할: **Storage Blob Data Contributor** |
| Role Assignment | VM → Azure OpenAI | 0 또는 2 | Scope: ai_services 스택 openai_id. 역할: **Cognitive Services User**, **Reader** |
| Role Assignment | VM → Spoke RG | 0 또는 1 | Scope: network 스택 spoke_resource_group_id. 역할: **Reader** |

※ 위 역할은 모두 **Monitoring VM의 Managed Identity (principal_id)** 에 부여됩니다. principal_id는 **compute** 스택 output에서 remote_state로 읽습니다.

---

## 3. 리소스 추가/생성/변경 시 메뉴얼

### 3.1 신규 리소스 추가 (예: VM에 역할 1개 더 부여)

1. `main.tf`에 `azurerm_role_assignment` 리소스 블록을 추가합니다.  
2. `scope`는 `data.terraform_remote_state.*.outputs.*` 로 대상 리소스 ID를 참조합니다.  
3. `principal_id`는 `local.vm_principal_id`(compute remote_state에서 가져온 값)를 사용합니다.  
4. `terraform plan` → `apply`로 반영합니다.  
5. **공통 모듈에 없는 리소스**가 아니므로 모듈 레포 수정은 필요 없습니다. (역할 할당은 스택에서 직접 리소스로 관리.)

### 3.2 기존 리소스 변경 (예: 역할 종류 변경, 대상 Scope 변경)

1. `main.tf`의 해당 `azurerm_role_assignment`에서 `role_definition_name` 또는 `scope` 수정.  
2. `terraform plan`으로 변경(또는 replace) 확인 후 `apply`로 적용.  
3. 역할 할당은 보통 **replace**가 되므로 plan에서 destroy + create 1건으로 나올 수 있습니다.

### 3.3 기존 리소스 삭제

1. 제거할 역할 할당의 `azurerm_role_assignment` 블록을 `main.tf`에서 삭제(또는 주석 처리).  
2. `terraform plan`으로 destroy 대상 확인 후 `apply`로 삭제.  
3. VM 자체를 삭제한 경우(compute 스택에서 enable_monitoring_vm = false): rbac 스택의 `local.vm_principal_id`가 null이 되어 대부분의 역할 할당이 count/for_each 0이 되므로 plan에서 destroy만 나옵니다. apply로 정리합니다.

### 3.4 공통 모듈(terraform-modules 레포) 수정이 필요한 경우

- RBAC 스택은 **모듈을 사용하지 않고** `main.tf`에 `azurerm_role_assignment`만 정의되어 있습니다.  
- 따라서 **모듈 레포 수정 → init -upgrade** 절차는 필요 없습니다.  
- 역할 추가/삭제/변경은 이 스택의 `main.tf`만 수정한 뒤 plan → apply 하면 됩니다.
