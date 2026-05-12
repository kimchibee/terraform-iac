# Terraform IaC 배포 가이드

Azure Hub/Spoke 인프라를 배포하는 3가지 방식을 설명합니다.
각 방식은 `azure-1`, `azure-2`, `azure-3` 폴더에 구현되어 있습니다.

---

## 공통 사전 조건

### 1. Terraform 설치

```bash
# tfenv 사용 시
tfenv install 1.14.6
tfenv use 1.14.6

# 버전 확인
terraform -version
```

### 2. Azure 인증

```bash
# 방법 A: Azure CLI 로그인 (로컬 배포)
az login
az account set --subscription "20e3a0f3-f1af-4cc5-8092-dc9b276a9911"

# 방법 B: Service Principal 환경변수 (CI 배포)
export ARM_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_CLIENT_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ARM_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 3. Azure Storage Account (State 저장소)

Terraform state를 저장할 Storage Account가 Azure에 존재해야 합니다.
이미 생성되어 있다면 이 단계는 건너뜁니다.

```bash
# 리소스 그룹 생성
az group create \
  --name terraform-state-rg \
  --location "Korea Central"

# Storage Account 생성
az storage account create \
  --name tfstatea9911 \
  --resource-group terraform-state-rg \
  --location "Korea Central" \
  --sku Standard_LRS

# Blob Container 생성
az storage container create \
  --name tfstate \
  --account-name tfstatea9911
```

### 4. 배포 순서 (스택 의존성)

스택은 반드시 아래 순서로 배포해야 합니다.
각 스택 내 leaf도 의존성 순서를 따릅니다.

```
01.network    ← 가장 먼저 (RG → VNet → Subnet → DNS → ...)
02.storage
03.shared-services
04.apim
05.ai-services
06.compute
07.identity
08.rbac
09.connectivity  ← 가장 마지막 (peering, diagnostics)
```

#### 01.network 내부 배포 순서

```
resource-group/hub-rg
resource-group/spoke-rg
    ↓
vnet/hub-vnet
vnet/spoke-vnet
    ↓
subnet/* (모든 서브넷)
    ↓
security-group/application-security-group/*
security-group/network-security-group/*
security-group/security-policy/*
security-group/network-security-rule/*
security-group/subnet-network-security-group-association/*
    ↓
route/*
    ↓
dns/private-dns-zone/*
dns/private-dns-zone-vnet-link/*
dns/dns-private-resolver/*
dns/dns-private-resolver-inbound-endpoint/*
    ↓
public-ip/* (선택)
virtual-network-gateway/* (선택)
```

---

## 방식 A — azure-1: backend.tf 하드코딩

`backend.tf`에 state 저장소 설정이 직접 입력되어 있어, 추가 설정 없이 바로 배포 가능합니다.

### 구조

```
azure-1/
├── 01.network/
│   └── resource-group/hub-rg/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars          ← 변수 값 (gitignore 대상)
│       ├── terraform.tfvars.example  ← 변수 값 템플릿
│       └── backend.tf               ← state 설정 하드코딩
├── ...
```

### backend.tf 예시

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-rg"
    storage_account_name = "tfstatea9911"
    container_name       = "tfstate"
    key                  = "01.network/resource-group/hub-rg/terraform.tfstate"
  }
}
```

### 배포 절차

```bash
# 1. terraform.tfvars 준비 (최초 1회)
cd azure-1/01.network/resource-group/hub-rg
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID 등 실제 값 입력

# 2. 초기화
terraform init

# 3. 계획 확인
terraform plan

# 4. 배포
terraform apply

# 5. 다음 leaf로 이동하여 반복
cd ../../vnet/hub-vnet
terraform init
terraform plan
terraform apply
```

### 장단점

| 장점 | 단점 |
|------|------|
| 가장 단순, 추가 도구 불필요 | backend 값 변경 시 67개 파일 모두 수정 필요 |
| CI 없이 로컬에서 바로 실행 가능 | storage_account_name이 코드에 포함 |
| 초보자도 이해 쉬움 | 환경(dev/prod) 분리 시 별도 폴더 필요 |

---

## 방식 B — azure-2: GitLab CI에서 backend.hcl 인라인 생성

코드에 backend 설정을 포함하지 않고, GitLab CI Variables에서 주입합니다.
CI/CD 파이프라인을 통한 배포에 최적화된 방식입니다.

### 구조

```
azure-2/
├── ci/
│   ├── terraform-base.yml            ← CI 템플릿 (plan/approve/apply)
│   └── generate-stack-pipeline.sh    ← child pipeline YAML 생성 스크립트
├── 01.network/
│   └── resource-group/hub-rg/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       └── backend.tf               ← 비어 있음 (CI에서 backend.hcl 생성)
├── ...
```

### 필요한 GitLab CI Variables

GitLab > Settings > CI/CD > Variables에 등록합니다.

| Variable | 예시 값 | Masked | 설명 |
|----------|--------|--------|------|
| `ARM_CLIENT_ID` | `xxxxxxxx-...` | Yes | Service Principal Client ID |
| `ARM_CLIENT_SECRET` | `xxxxxxxx-...` | Yes | Service Principal Secret |
| `ARM_TENANT_ID` | `xxxxxxxx-...` | Yes | Azure AD Tenant ID |
| `HUB_SUBSCRIPTION_ID` | `20e3a0f3-...` | Yes | Hub 구독 ID |
| `SPOKE_SUBSCRIPTION_ID` | `20e3a0f3-...` | Yes | Spoke 구독 ID |
| `BACKEND_RG` | `terraform-state-rg` | No | State 리소스 그룹 |
| `BACKEND_SA` | `tfstatea9911` | No | State Storage Account |
| `BACKEND_CONTAINER` | `tfstate` | No | State Blob Container |

### CI 배포 절차

```bash
# 1. child pipeline YAML 생성 (CI에서 자동 실행)
bash azure-2/ci/generate-stack-pipeline.sh 01.network

# 2. CI 파이프라인 흐름 (자동):
#    plan (backend.hcl 생성 → terraform init → terraform plan)
#      ↓
#    approve (수동 승인 대기)
#      ↓
#    apply (terraform apply)
```

### 로컬 배포 절차

CI 없이 로컬에서 배포할 경우, backend.hcl을 수동으로 생성합니다.

```bash
# 1. leaf 디렉토리 이동
cd azure-2/01.network/resource-group/hub-rg

# 2. backend.hcl 수동 생성
cat > backend.hcl <<HCL
resource_group_name  = "terraform-state-rg"
storage_account_name = "tfstatea9911"
container_name       = "tfstate"
key                  = "01.network/resource-group/hub-rg/terraform.tfstate"
HCL

# 3. 초기화 및 배포
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# 4. 다음 leaf로 이동하여 반복
```

### 장단점

| 장점 | 단점 |
|------|------|
| 코드에 민감 정보 없음 | GitLab Runner 인프라 필요 |
| CI Variables로 환경 분리 용이 | 로컬 배포 시 backend.hcl 수동 생성 필요 |
| 수동 승인 단계로 안전한 배포 | .gitlab-ci.yml 별도 작성 필요 |

---

## 방식 C — azure-3: Wrapper 스크립트로 tfvars에서 backend 추출

`terraform.tfvars`에 이미 있는 backend 관련 변수를 스크립트가 읽어서
`backend.hcl`을 자동 생성합니다.

### 구조

```
azure-3/
├── scripts/
│   └── tf.sh                        ← wrapper 스크립트
├── 01.network/
│   └── resource-group/hub-rg/
│       ├── main.tf
│       ├── variables.tf
│       ├── terraform.tfvars          ← backend 값 + 변수 값 모두 포함
│       └── backend.tf               ← 비어 있음 (tf.sh가 backend.hcl 생성)
├── ...
```

### terraform.tfvars 예시

```hcl
project_name = "test"
environment  = "dev"
location     = "Korea Central"

hub_subscription_id = "20e3a0f3-f1af-4cc5-8092-dc9b276a9911"

# backend 설정 (tf.sh가 이 값을 읽어 backend.hcl 생성)
backend_resource_group_name  = "terraform-state-rg"
backend_storage_account_name = "tfstatea9911"
backend_container_name       = "tfstate"

tags = {
  ManagedBy   = "Terraform"
  Environment = "dev"
}
```

### 배포 절차

```bash
# 1. terraform.tfvars 준비 (최초 1회)
cd azure-3/01.network/resource-group/hub-rg
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 편집: 구독 ID, backend 값 등 실제 값 입력

# 2. 초기화 (backend.hcl 자동 생성 + terraform init)
../../scripts/tf.sh init

# 3. 계획 확인
../../scripts/tf.sh plan

# 4. 배포
../../scripts/tf.sh apply

# 5. 다음 leaf로 이동하여 반복
cd ../../vnet/hub-vnet
../../../../scripts/tf.sh init
../../../../scripts/tf.sh plan
../../../../scripts/tf.sh apply
```

### tf.sh 사용법

```bash
# 기본 명령
../../scripts/tf.sh init      # backend.hcl 자동 생성 + terraform init
../../scripts/tf.sh plan      # terraform plan
../../scripts/tf.sh apply     # terraform apply
../../scripts/tf.sh destroy   # terraform destroy

# 추가 인자 전달
../../scripts/tf.sh plan -target=module.hub_vnet
../../scripts/tf.sh apply -auto-approve
```

### 장단점

| 장점 | 단점 |
|------|------|
| backend 값이 tfvars에 집중 (한 곳 관리) | wrapper 스크립트 의존 |
| 코드(backend.tf)에 민감 정보 없음 | 스크립트 상대 경로 입력 번거로움 |
| CI 없이 로컬 배포 가능 | tfvars는 gitignore 대상 → 팀 공유 시 example 복사 필요 |

---

## 3가지 방식 비교

| 항목 | azure-1 (하드코딩) | azure-2 (CI 인라인) | azure-3 (wrapper) |
|------|-------------------|--------------------|--------------------|
| **로컬 배포** | `terraform init` 바로 가능 | backend.hcl 수동 생성 필요 | `tf.sh init`으로 가능 |
| **CI 배포** | 가능 | 최적 (CI Variables 활용) | 가능 (tf.sh 호출) |
| **민감 정보 위치** | backend.tf (코드) | CI Variables | tfvars (gitignore) |
| **환경 분리** | 파일 수정 필요 | CI Variables만 변경 | tfvars만 변경 |
| **추가 파일** | 없음 | ci/ 폴더 | scripts/tf.sh |
| **팀 협업** | 코드에 값이 있어 공유 쉬움 | CI 설정만 공유 | example 복사 후 값 입력 |
| **권장 대상** | 개인/테스트 환경 | 팀/운영 환경 (CI/CD) | 개인/소규모 팀 |

---

## 리소스 삭제 (역순)

배포한 리소스를 삭제할 때는 **배포의 역순**으로 진행합니다.

```
09.connectivity → 08.rbac → 07.identity → 06.compute
→ 05.ai-services → 04.apim → 03.shared-services
→ 02.storage → 01.network
```

```bash
# 예시 (azure-1 기준)
cd azure-1/09.connectivity/peering/hub-to-spoke
terraform destroy

cd ../spoke-to-hub
terraform destroy

# ... 역순으로 모든 leaf에서 terraform destroy 실행
```
