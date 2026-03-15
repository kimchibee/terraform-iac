# 배포 순서별 명령어 (복사·붙여넣기용)

아래 각 코드 블록을 **순서대로** 복사한 뒤 터미널에 붙여넣어 실행하세요.

- **시작 위치**: 터미널을 열고 프로젝트 루트(`terraform-iac` 폴더)로 이동한 뒤, 아래 블록을 순서대로 복사·붙여넣기.
- **파일 복사**: `cp` (Git Bash/WSL/macOS/Linux). Windows CMD에서는 `copy` 로 바꿔서 실행.
- **backend.hcl 생성(2번)**: Bash 필요. Windows에서는 Git Bash 또는 WSL에서 실행.
- **terraform apply**: 기본적으로 plan 출력 후 `Enter a value:` 에 **yes** 를 입력해야 적용됩니다. 확인 없이 한 번에 적용하려면 `terraform apply -var-file=terraform.tfvars -auto-approve` 로 바꿔서 실행하세요. (실수 적용 방지를 위해 가급적 plan 확인 후 yes 입력을 권장합니다.)

---

## 0. 사전 준비 — Azure 로그인 및 구독

```bash
az login
az account list --query "[].{name:name, id:id}" -o table
az account set --subscription "YOUR_HUB_SUBSCRIPTION_ID"
```
→ `YOUR_HUB_SUBSCRIPTION_ID` 를 실제 Hub 구독 ID로 바꾼 뒤 실행.

---

## 0-2. 사전 준비 — Resource Provider 등록

```bash
az provider register --namespace Microsoft.OperationalInsights
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage
az provider register --namespace Microsoft.KeyVault
az provider register --namespace Microsoft.Compute
az provider show --namespace Microsoft.Network --query "registrationState" -o tsv
```

---

## 1. Bootstrap (Backend Storage)

(프로젝트 루트에서 실행)

```bash
cd bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
terraform output
```
→ 적용 전 `terraform.tfvars` 에 `resource_group_name`, `storage_account_name`, `container_name`, `location` 등 필수 값 입력. (Windows CMD: `cp` → `copy`)

---

## 2. backend.hcl 생성 (Bootstrap 적용 후 1회)

(Bash 사용. 프로젝트 루트에서 실행. 1번 직후라면 현재 디렉터리가 `bootstrap/backend` 이므로 먼저 루트로 이동)

```bash
cd ../..
bash ./scripts/generate-backend-hcl.sh
```

---

## 3. Network

(프로젝트 루트에서 실행)

```bash
cd azure/dev/network
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate 
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
terraform output
```
→ `terraform.tfvars` 에 `hub_subscription_id`, `spoke_subscription_id`, `project_name`, `backend_*` 등 설정 후 apply.

---

## 4. Storage

(프로젝트 루트에서 실행)

```bash
cd azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars -auto-approve
terraform output
```

---

## 5. Shared-services

(프로젝트 루트에서 실행)

```bash
cd ../../shared-services
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 6. APIM

(프로젝트 루트에서 실행)

```bash
cd azure/dev/apim
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 7. AI-services

(프로젝트 루트에서 실행)

```bash
cd azure/dev/ai-services
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 8. Compute

(프로젝트 루트에서 실행)

```bash
cd azure/dev/compute
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 9. RBAC

(프로젝트 루트에서 실행)

```bash
cd azure/dev/rbac
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 10. Connectivity

(프로젝트 루트에서 실행)

```bash
cd azure/dev/connectivity
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

## 배포 순서 요약

| 순서 | 스택 | 디렉터리 |
|------|------|----------|
| 0 | 사전 준비 | - |
| 1 | Bootstrap | `bootstrap/backend` |
| 2 | backend.hcl 생성 | 루트 `./scripts/generate-backend-hcl.sh` |
| 3 | network | `azure/dev/network` |
| 4 | storage | `azure/dev/storage` |
| 5 | shared-services | `azure/dev/shared-services` |
| 6 | apim | `azure/dev/apim` |
| 7 | ai-services | `azure/dev/ai-services` |
| 8 | compute | `azure/dev/compute` |
| 9 | rbac | `azure/dev/rbac` |
| 10 | connectivity | `azure/dev/connectivity` |

**롤백 시**: 위 역순으로 각 스택 디렉터리에서 `terraform destroy -var-file=terraform.tfvars` 실행.

- **점검 기준표**: [DEPLOYMENT_VERIFICATION_CHECKLIST.md](DEPLOYMENT_VERIFICATION_CHECKLIST.md)
- **전체 배포 가이드**: 루트 `README.md` 3장
