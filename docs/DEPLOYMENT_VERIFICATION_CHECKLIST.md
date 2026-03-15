# 스택별 배포 점검 기준표

Bootstrap부터 각 스택을 순서대로 배포하면서 검증할 때 사용하는 점검 기준표입니다.  
각 단계마다 **점검 항목**을 통과한 뒤 다음 스택으로 진행합니다.

---

## 0. 사전 준비 (전체 공통)

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 0-1 | Azure CLI 로그인 | `az account show` | 구독 정보가 출력됨, 오류 없음 |
| 0-2 | Hub / Spoke 구독 ID 확인 | `az account list --query "[].{name:name, id:id}" -o table` | 사용할 구독 ID 2개(또는 1개) 확보 |
| 0-3 | Resource Provider 등록 | `az provider show --namespace Microsoft.Network --query "registrationState" -o tsv` 등 | `Registered` 출력 (필요 시 `az provider register --namespace Microsoft.xxx`) |
| 0-4 | Terraform 버전 | `terraform version` | 1.5 이상 (README 기준 1.9 이상 권장) |
| 0-5 | Backend Storage 이름 확정 | `bootstrap/backend/terraform.tfvars` (예시 복사 후 편집) | `storage_account_name`이 Azure 전역 유일(소문자·숫자 3~24자) |

---

## 1. Bootstrap (backend)

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 1-1 | 변수 파일 존재 | `bootstrap/backend/terraform.tfvars` 확인 | `resource_group_name`, `storage_account_name`, `container_name`, `location` 등 필수 변수 존재 |
| 1-2 | init 성공 (로컬 backend) | `cd bootstrap/backend && terraform init` | 오류 없이 "Terraform has been successfully initialized" |
| 1-3 | validate 성공 | `terraform validate` | "Success! The configuration is valid." |
| 1-4 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, 생성 예정 리소스: RG 1, Storage Account 1, Container 1 (및 선택 PE) |
| 1-5 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 1-6 | output 확인 | `terraform output` | `resource_group_name`, `storage_account_name`, `container_name` 등 출력 |
| 1-7 | backend.hcl 생성 스크립트 실행 | 프로젝트 루트에서 `./scripts/generate-backend-hcl.sh` (Bash) | `CREATED .../backend.hcl` 로 8개 스택 디렉터리에 `backend.hcl` 생성됨 |

---

## 2. Network

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 2-1 | backend.hcl 존재 | `azure/dev/network/backend.hcl` | `resource_group_name`, `storage_account_name`, `container_name`, `key` 값 있음 |
| 2-2 | tfvars 준비 | `azure/dev/network/terraform.tfvars` | `hub_subscription_id`, `spoke_subscription_id`, `project_name`, `hub_vnet_address_space`, `hub_subnets`, `spoke_*`, `backend_*` 등 |
| 2-3 | init 성공 (원격 backend) | `cd azure/dev/network && terraform init -backend-config=backend.hcl` | Backend "azurerm" 초기화 성공, state 위치 확인 |
| 2-4 | validate 성공 | `terraform validate` | "Success! The configuration is valid." |
| 2-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, Hub VNet·서브넷·Spoke VNet·NSG·(선택) keyvault-sg, vm-access-sg 등 생성/변경 예정 표시 |
| 2-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 2-7 | output 확인 | `terraform output` | `hub_resource_group_name`, `hub_subnet_ids`, `hub_vnet_id`, `spoke_vnet_id`, (옵션) `keyvault_clients_asg_id`, `vm_allowed_clients_asg_id` 등 |

---

## 3. Storage

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 3-1 | backend.hcl 존재 | `azure/dev/storage/backend.hcl` | 동일 형식 |
| 3-2 | tfvars 준비 | `azure/dev/storage/terraform.tfvars` | `hub_subscription_id`, `backend_*`, `enable_key_vault`, (선택) `monitoring_vm_identity_principal_id` |
| 3-3 | init 성공 | `cd azure/dev/storage && terraform init -backend-config=backend.hcl` | 성공, network state 조회 가능 |
| 3-4 | validate 성공 | `terraform validate` | Success |
| 3-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state.network 참조 성공, Key Vault·Storage·PE 등 생성 예정 |
| 3-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 3-7 | output 확인 | `terraform output` | `key_vault_id`, `hub_resource_group_name` 등 (rbac 등에서 참조) |

---

## 4. Shared-services

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 4-1 | backend.hcl 존재 | `azure/dev/shared-services/backend.hcl` | 동일 형식 |
| 4-2 | tfvars 준비 | `azure/dev/shared-services/terraform.tfvars` | `hub_subscription_id`, `backend_*`, `log_analytics_retention_days`, `enable_shared_services` |
| 4-3 | init 성공 | `cd azure/dev/shared-services && terraform init -backend-config=backend.hcl` | 성공 |
| 4-4 | validate 성공 | `terraform validate` | Success |
| 4-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state.network 참조, Log Analytics·Solutions 등 생성 예정 |
| 4-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 4-7 | output 확인 | `terraform output` | Log Analytics Workspace ID 등 (apim·ai-services에서 참조) |

---

## 5. APIM

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 5-1 | backend.hcl 존재 | `azure/dev/apim/backend.hcl` | 동일 형식 |
| 5-2 | tfvars 준비 | `azure/dev/apim/terraform.tfvars` | `hub_subscription_id`, `spoke_subscription_id`, `backend_*`, `apim_sku_name`, `apim_publisher_*` |
| 5-3 | init 성공 | `cd azure/dev/apim && terraform init -backend-config=backend.hcl` | 성공 |
| 5-4 | validate 성공 | `terraform validate` | Success |
| 5-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state(network, storage, shared_services) 참조, APIM 생성 예정 |
| 5-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 (30분~1시간 소요 가능) |
| 5-7 | output 확인 | `terraform output` | `apim_id` 등 (rbac·ai-services에서 참조) |

---

## 6. AI-services

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 6-1 | backend.hcl 존재 | `azure/dev/ai-services/backend.hcl` | 동일 형식 |
| 6-2 | tfvars 준비 | `azure/dev/ai-services/terraform.tfvars` | `hub_subscription_id`, `spoke_subscription_id`, `backend_*`, `openai_sku`, `openai_deployments`(쿼터 없으면 `[]`) |
| 6-3 | init 성공 | `cd azure/dev/ai-services && terraform init -backend-config=backend.hcl` | 성공 |
| 6-4 | validate 성공 | `terraform validate` | Success |
| 6-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state(network, storage, shared_services) 참조, OpenAI·AI Foundry·PE 등 생성 예정 |
| 6-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 6-7 | output 확인 | `terraform output` | `openai_id`, `key_vault_id`, `storage_account_id` 등 (rbac에서 참조) |

---

## 7. Compute

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 7-1 | backend.hcl 존재 | `azure/dev/compute/backend.hcl` | 동일 형식 |
| 7-2 | tfvars 준비 | `azure/dev/compute/terraform.tfvars` | `hub_subscription_id`, `backend_*`, VM별 변수(`linux_monitoring_vm_*`, `windows_example_*`), (선택) `application_security_group_keys` |
| 7-3 | init 성공 | `cd azure/dev/compute && terraform init -backend-config=backend.hcl` | 성공, remote_state.network 조회 가능 |
| 7-4 | validate 성공 | `terraform validate` | Success |
| 7-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state.network에서 hub_subnet_ids·asg_id 등 참조, VM·NIC·ASG 연결 생성 예정 |
| 7-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 7-7 | output 확인 | `terraform output` | `monitoring_vm_identity_principal_id`, `linux_monitoring_vm_id` 등 (rbac·storage에서 참조) |
| 7-8 | ASG 연결 확인 | Azure Portal 또는 `az network nic show` | VM NIC에 keyvault_clients·vm_allowed_clients ASG 연결됨 |

---

## 8. RBAC

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 8-1 | backend.hcl 존재 | `azure/dev/rbac/backend.hcl` | 동일 형식 |
| 8-2 | tfvars 준비 | `azure/dev/rbac/terraform.tfvars` | `hub_subscription_id`, `backend_*`, `enable_monitoring_vm_roles`, `enable_key_vault_roles`, (선택) 그룹 ID·`resource_iam_assignments` |
| 8-3 | init 성공 | `cd azure/dev/rbac && terraform init -backend-config=backend.hcl` | 성공, remote_state(compute, network, storage, ai_services, apim) 조회 가능 |
| 8-4 | validate 성공 | `terraform validate` | Success |
| 8-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, compute output(principal_id)·storage/network/ai_services/apim output(scope) 참조, 역할 할당 생성 예정 |
| 8-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 8-7 | output 확인 | `terraform output` | (정의된 경우) 역할 할당 관련 output |
| 8-8 | 역할 할당 확인 | Azure Portal → Key Vault / Storage 등 → Access control (IAM) | Monitoring VM Identity 등에 예상 역할 표시 |

---

## 9. Connectivity

| # | 점검 항목 | 확인 방법 | 통과 기준 |
|---|-----------|-----------|------------|
| 9-1 | backend.hcl 존재 | `azure/dev/connectivity/backend.hcl` | 동일 형식 |
| 9-2 | tfvars 준비 | `azure/dev/connectivity/terraform.tfvars` | `hub_subscription_id`, `spoke_subscription_id`, `backend_*`, `project_name` |
| 9-3 | init 성공 | `cd azure/dev/connectivity && terraform init -backend-config=backend.hcl` | 성공 |
| 9-4 | validate 성공 | `terraform validate` | Success |
| 9-5 | plan 성공 | `terraform plan -var-file=terraform.tfvars` | 오류 없음, remote_state(network, storage, shared_services) 참조, Peering·진단 설정 생성 예정 |
| 9-6 | apply 성공 | `terraform apply -var-file=terraform.tfvars` | 오류 없이 적용 완료 |
| 9-7 | output 확인 | `terraform output` | (정의된 경우) Peering ID 등 |
| 9-8 | Peering 확인 | Azure Portal → VNet → Peerings | Hub ↔ Spoke Peering 2개 존재 |

---

## 요약: 스택별 필수 선행 조건

| 스택 | 선행 완료 필요 | 점검 핵심 |
|------|----------------|-----------|
| Bootstrap | 없음 | init(로컬), plan/apply, backend.hcl 생성 스크립트 |
| network | Bootstrap + backend.hcl | init(-backend-config), remote_state 없음 |
| storage | network (+ 선택: compute) | remote_state.network, (선택) compute |
| shared-services | network | remote_state.network |
| apim | network, storage, shared-services | remote_state 3개 |
| ai-services | network, storage, shared-services | remote_state 3개 |
| compute | network | remote_state.network (subnet, asg) |
| rbac | compute, network, storage, ai-services(, apim) | remote_state 5개, principal_id·scope |
| connectivity | network, storage, shared-services | remote_state 3개, Peering·진단 |

이 기준표대로 각 스택을 배포한 뒤, **배포 순서별 명령어**는 [`docs/DEPLOYMENT_COMMANDS.md`](DEPLOYMENT_COMMANDS.md)를 참고하세요.
