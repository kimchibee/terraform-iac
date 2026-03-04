# Terraform & Azure 인프라 통합 가이드

이 문서는 **terraform-iac**과 **terraform-modules** 두 레포를 함께 사용하는 방식을 정리한 통합 가이드입니다.  
Terraform을 처음 접하는 IT 엔지니어도 따라올 수 있도록 기초 개념과 용어 풀이를 포함했습니다.

---

## 1. Terraform에 대한 기초 개념

### 1.1 Terraform이란

**Terraform**은 **인프라를 코드(Infrastructure as Code, IaC)**로 정의하고, 그 코드를 실행해 클라우드/온프레미스 리소스를 **생성·변경·삭제**하는 도구입니다.

- **선언형(Declarative)**: "어떤 리소스가 있어야 한다"만 작성하면, Terraform이 "현재 상태와의 차이"를 계산해 필요한 변경만 수행합니다.
- **상태(State)**: Terraform은 "지금 관리 중인 리소스 목록과 속성"을 **State 파일**에 저장합니다. 이 파일을 기준으로 `plan`/`apply` 시 무엇을 바꿀지 결정합니다.
  - *State: Terraform이 만든 리소스의 ID·속성을 저장한 파일. 보통 원격(예: Azure Storage)에 저장해 팀이 공유합니다.*

### 1.2 주요 용어

| 용어 | 설명 |
|------|------|
| **HCL (HashiCorp Configuration Language)** | Terraform 설정 파일(`.tf`)에 쓰는 문법. 리소스, 변수, 출력 등을 정의합니다. |
| **Provider (프로바이더)** | 특정 클라우드/서비스(Azure, AWS 등)와 대화하는 플러그인. 예: `hashicorp/azurerm` → Azure 리소스 생성·관리. |
| **Resource (리소스)** | 실제로 생성되는 하나의 인프라 단위. 예: `azurerm_resource_group`, `azurerm_virtual_network`. |
| **Module (모듈)** | 여러 리소스를 묶어 재사용 가능한 단위로 만든 것. 다른 디렉터리나 Git 주소로 참조할 수 있습니다. |
| **Variable (변수)** | 값을 바깥에서 넣을 수 있게 하는 입력. `terraform.tfvars`나 `-var`로 값을 넘깁니다. |
| **Output (출력)** | 모듈 또는 스택 실행 후 밖으로 내보내는 값. 다른 스택에서 `remote_state`로 참조할 수 있습니다. |
| **Backend (백엔드)** | State 파일을 저장하는 위치. `local`(로컬 파일) 또는 `azurerm`(Azure Storage) 등. 팀 작업 시 원격 Backend 사용이 일반적입니다. |

### 1.3 기본 명령 흐름

```
terraform init    → 프로바이더·모듈 다운로드, Backend 초기화 (최초 1회 또는 설정 변경 시)
terraform plan    → "실제로 무엇이 바뀌는지" 미리 보기 (리소스 생성/변경/삭제 계획)
terraform apply   → plan 내용을 반영해 실제 Azure(또는 대상)에 적용
terraform destroy → 해당 디렉터리에서 관리 중인 리소스 전부 삭제 (선택 시에만 사용)
```

- *init: 작업 디렉터리를 Terraform이 사용할 수 있게 준비하는 단계.*  
- *plan: 코드와 State를 비교해 "추가/수정/삭제할 것" 목록을 보여 줍니다. 리소스는 아직 변경되지 않습니다.*  
- *apply: plan에서 제안한 변경을 실제로 수행합니다.*

---

## 2. Terraform Azure AVM에 대한 기초 개념

### 2.1 AVM이란

**AVM(Azure Verified Modules)**은 **Microsoft가 검증·유지보수하는 Terraform 모듈 세트**입니다. Azure 리소스를 만들 때 "공식에 가까운" 구현을 쓰기 위한 표준입니다.

- **공식성**: Azure 팀이 설계·테스트·문서화를 담당하므로, 커스텀 리소스만 쓸 때보다 **동작 일관성·보안·모범 사례**를 기대하기 쉽습니다.
- **Terraform Registry**: [registry.terraform.io](https://registry.terraform.io)에서 `Azure/avm-res-...` 형태로 검색할 수 있습니다.
  - *Registry: Terraform 모듈·프로바이더를 공개하는 공식 저장소.*

### 2.2 AVM 모듈 사용 방식

- **직접 참조**: Terraform 코드에서 `source = "Azure/avm-res-keyvault-vault/azurerm"` 처럼 Registry 주소와 **version**을 지정해 사용합니다.
- **래퍼(Wrapper)**: AVM 모듈을 그대로 노출하지 않고, **우리 쪽 변수/출력 이름**으로 한 번 감싼 모듈을 만드는 방식입니다.  
  - *래퍼: 외부 모듈(AVM)을 내부에서 호출하고, 우리 프로젝트에 맞는 변수·출력 이름으로 다시 노출하는 작은 모듈.*  
  - 이 프로젝트의 **terraform-modules**에서 `key-vault`, `log-analytics-workspace`, `resource-group`, `private-endpoint` 등이 AVM을 래퍼로 사용합니다.

### 2.3 AVM과 Provider 버전

- AVM 모듈은 특정 **Terraform 버전**(예: 1.9 이상)과 **azurerm Provider 버전**을 요구할 수 있습니다.
- 이 레포에서는 **shared-services** 스택이 AVM 기반 모듈을 쓰므로, Terraform **1.9+** 를 사용합니다.

### 2.4 AVM과 azurerm 차이

*azurerm*은 Terraform이 Azure와 통신할 때 쓰는 **프로바이더(Provider)**이고, *AVM*은 그 위에서 동작하는 **모듈 세트**입니다. 아래 표로 구분해서 볼 수 있습니다.

| 구분 | **azurerm** | **AVM (Azure Verified Modules)** |
|------|-------------|-----------------------------------|
| **정의** | Terraform **Provider**. Azure REST API를 호출하는 플러그인. | Azure가 검증·제공하는 **Terraform 모듈** 모음. 내부적으로 azurerm 리소스를 사용함. |
| **제공 주체** | HashiCorp (Terraform 제작사)가 유지보수. | Microsoft(Azure)가 설계·검증·문서화. |
| **Terraform에서의 사용 방식** | `resource "azurerm_xxx" "이름" { ... }` 형태로 **리소스 블록**을 직접 작성. | `module "이름" { source = "Azure/avm-res-.../azurerm" ... }` 형태로 **모듈**을 호출. |
| **추상화 수준** | **저수준**. VM 하나, VNet 하나처럼 리소스 단위로 세부 속성을 직접 지정. | **고수준**. “Key Vault 한 개”, “Storage Account 한 개”처럼 시나리오 단위. 권장 설정·의존성·네이밍 규칙이 모듈 안에 포함됨. |
| **버전 관리** | Provider 버전만 지정. 예: `required_providers { azurerm = "~> 3.75" }` | 모듈별로 **버전** 지정. 예: `version = "0.10.2"`. 리소스 스키마 변경에 맞춰 모듈 버전을 올려서 대응. |
| **유지보수·보안** | HashiCorp가 Azure API 변경에 맞춰 Provider 업데이트. 리소스 단위. | Azure 팀이 모범 사례·보안 권장을 반영해 모듈 업데이트. 리소스 조합·패턴 단위. |
| **적합한 경우** | 세밀한 제어, 커스텀 조합, 이미 안정된 기존 코드 유지. | 새로 리소스 추가·표준 패턴 적용·팀 표준화·빠른 구성 시. |

**요약**: azurerm은 “Azure와 대화하는 도구(Provider)”이고, AVM은 “그 도구를 이용해 Azure가 권장하는 방식으로 리소스를 만드는 모듈 세트”입니다. 이 레포에서는 AVM을 **래퍼**로 감싸서 사용해, 동일한 인터페이스를 유지하면서 AVM의 이점을 활용합니다.

* **azurerm vs Azure Resource Manager (ARM)**: **ARM**은 Azure의 실제 배포·관리 서비스(API)이고, **azurerm**은 Terraform이 그 ARM API를 호출할 때 쓰는 **프로바이더 이름**입니다. 즉, ARM = Azure 쪽 시스템, azurerm = Terraform 쪽 클라이언트(플러그인). 동일한 것이 아니라 “azurerm이 ARM을 사용한다”는 관계입니다.

---

## 3. 현재 레포를 왜 분리하여 구성하였는지

### 3.1 두 레포의 역할

| 레포 | 역할 | 비유 |
|------|------|------|
| **terraform-iac** | **배포 실행**의 주체. 스택별 디렉터리, Backend/Provider 설정, 변수 파일(`.tfvars`) 보유. 여기서 `terraform init / plan / apply` 실행. | "설계도 + 시공 순서를 갖고 실제로 짓는 쪽" |
| **terraform-modules** | **재사용 가능한 부품(모듈)** 만 보유. VNet, Key Vault, VM 등 공통 모듈 정의. **여기서는 apply 하지 않음.** | "부품 창고" |

- *레포(Repository): Git으로 관리하는 코드 저장소. 보통 GitHub/GitLab 등에 하나의 프로젝트 단위로 존재.*

### 3.2 분리했을 때의 이점

1. **관심사 분리**: "무엇을 배포할지(스택·환경 설정)"와 "어떤 부품을 쓸지(모듈 구현)"를 나누어, 각 레포의 목적이 분명해집니다.
2. **재사용**: terraform-modules의 모듈은 다른 IaC 프로젝트에서도 `source = "git::..."` 로 가져다 쓸 수 있습니다.
3. **권한·배포 주기 분리**: 모듈 수정은 별도 브랜치/PR로 관리하고, IaC 레포는 "어떤 ref(태그/브랜치)의 모듈을 쓸지"만 바꾸면 됩니다.
4. **State와 코드 분리**: 실제 State는 terraform-iac의 Backend 설정에 따라 Azure Storage 등에 저장되며, 모듈 레포에는 State가 없습니다.

### 3.3 스택(Stack) 분리의 이유

- **스택**: 이 문서에서는 `azure/dev/` 아래 **한 디렉터리 = 한 스택**입니다. (network, storage, shared-services, apim, ai-services, compute, connectivity)
- **스택별 State 분리**: 스택마다 **서로 다른 State 파일**을 사용하므로,
  - 한 스택만 **배포·롤백**할 수 있고,
  - 다른 스택에 영향을 주지 않고 **해당 스택만 plan/apply** 할 수 있습니다.
- **의존성**: 뒤쪽 스택이 앞쪽 스택의 **출력(예: VNet ID, Subnet ID)**을 `terraform_remote_state` 데이터 소스로 읽어 옵니다. 따라서 **배포 순서(1→2→…→7)**를 지켜야 합니다.
  - *remote_state: 다른 스택의 State 파일을 읽어 그 스택의 output 값을 가져오는 기능.*

---

## 4. Terraform Azure AVM을 사용할 때의 이점 (관리 편의성·확장)

### 4.1 관리 편의성

- **일관된 인터페이스**: AVM 모듈은 Azure 권장 패턴을 따르므로, "어떤 리소스를 어떻게 켜고 끄는지"가 문서화되어 있고 예측 가능합니다.
- **버전 고정**: 모듈에서 `version = "0.10.2"` 처럼 **고정 버전**을 쓰면, AVM이 업데이트되어도 우리가 선택한 시점까지의 동작을 유지할 수 있습니다. 필요할 때만 버전을 올리면 됩니다.
- **유지보수 부담 감소**: 리소스 정의를 직접 길게 쓰지 않고 AVM(또는 AVM 래퍼)에 맡기면, 보안 패치·API 변경 대응을 공식 쪽에 많이 의존할 수 있습니다.

### 4.2 인프라 확장 시

- **새 리소스 추가**: Azure에서 권장하는 새 서비스를 AVM으로 쓰면, Registry에서 해당 AVM 모듈을 찾아 **terraform-modules**에 래퍼를 추가한 뒤, **terraform-iac**의 해당 스택에서 모듈만 호출하면 됩니다. 처음부터 리소스 블록을 길게 작성할 필요가 줄어듭니다.
- **멀티 환경(dev/stage/prod)**: 같은 모듈을 다른 변수(예: 다른 `terraform.tfvars`)로 여러 번 적용하면 됩니다. AVM 래퍼가 일관되어 있어 환경 간 설정 차이만 관리하면 됩니다.
- **팀 온보딩**: "공식 AVM + 우리 래퍼" 구조가 정리되어 있으면, 새 멤버가 "어디서 무엇을 바꾸면 되는지" 파악하기 쉽습니다.

---

## 5. 서비스 배포 — 명령어만 나열

아래 순서대로 실행. 각 스택 디렉터리에서 `terraform.tfvars`·`backend.hcl` 준비 후 진행.

**사전:** `az login` / Terraform 1.9+ / 구독 권한 확인. 프로젝트 루트 기준 경로.

---

**1) Bootstrap (최초 1회)**

```bash
cd bootstrap/backend
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정 후
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

---

**2) network**

```bash
cd azure/dev/network
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 수정
# backend.hcl 생성 (resource_group_name, storage_account_name, container_name, key = "azure/dev/network/terraform.tfstate")
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**3) storage**

```bash
cd azure/dev/storage
cp terraform.tfvars.example terraform.tfvars
# backend.hcl 의 key = "azure/dev/storage/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**4) shared-services**

```bash
cd azure/dev/shared-services
cp terraform.tfvars.example terraform.tfvars
# backend.hcl key = "azure/dev/shared-services/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**5) apim**

```bash
cd azure/dev/apim
cp terraform.tfvars.example terraform.tfvars
# backend.hcl key = "azure/dev/apim/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**6) ai-services**

```bash
cd azure/dev/ai-services
cp terraform.tfvars.example terraform.tfvars
# backend.hcl key = "azure/dev/ai-services/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**7) compute**

```bash
cd azure/dev/compute
cp terraform.tfvars.example terraform.tfvars
# backend.hcl key = "azure/dev/compute/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**8) connectivity**

```bash
cd azure/dev/connectivity
cp terraform.tfvars.example terraform.tfvars
# backend.hcl key = "azure/dev/connectivity/terraform.tfstate"
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

---

**backend.hcl 예시 (각 스택에서 key 만 변경):**

```hcl
resource_group_name  = "terraform-state-rg"
storage_account_name = "terraformstate"
container_name       = "tfstate"
key                  = "azure/dev/network/terraform.tfstate"
```

---

## 6. IaC & Modules 레포에서 리소스 추가·변경·삭제 메뉴얼

### 6.1 어디를 수정하는지 (정리)

| 하고 싶은 일 | 수정 위치 | 비고 |
|--------------|-----------|------|
| **기존 스택에 리소스 추가** (예: network 스택에 서브넷 하나 더) | **terraform-iac** 해당 스택 디렉터리 (`azure/dev/<스택명>/`) | `main.tf` 또는 해당 모듈 호출부에 리소스/모듈 블록 추가. 변수는 `variables.tf`, `terraform.tfvars` 활용. |
| **공통 모듈의 동작/인터페이스 변경** (예: Key Vault 모듈에 옵션 추가) | **terraform-modules** 해당 모듈 폴더 (`terraform_modules/<모듈명>/`) | `variables.tf`, `main.tf`, `outputs.tf` 수정. terraform-iac에서는 `terraform init -upgrade`로 새 모듈 코드 반영. |
| **새 공통 모듈 추가** (예: 새 AVM 기반 모듈) | **terraform-modules** 에 새 폴더 추가 후, **terraform-iac** 에서 참조 | terraform-modules에 `terraform_modules/새모듈/` 추가 → terraform-iac의 사용할 스택 `main.tf`에서 `module` 블록과 `source = "git::...terraform-modules...//terraform_modules/새모듈"` 추가. |
| **리소스 삭제** | 해당 리소스/모듈이 정의된 **파일**에서 해당 블록 제거 | terraform-iac이면 해당 스택 디렉터리, 모듈 내부 리소스면 terraform-modules 해당 모듈. 삭제 후 `plan`으로 "destroy" 계획 확인 후 `apply`. |

### 6.2 리소스 추가 절차 (예: network 스택에 리소스 추가)

1. **terraform-iac** 저장소에서 `azure/dev/network/` 로 이동.
2. `main.tf` 또는 적절한 `.tf` 파일을 열고, 추가할 **resource** 또는 **module** 블록을 작성합니다.  
   - 기존 **terraform-modules** 모듈을 쓰는 경우: `module "이름" { source = "git::...terraform-modules.git//terraform_modules/모듈명?ref=main" ... }` 형태로 추가하고, 필요한 변수를 채웁니다.
3. 새 변수가 필요하면 `variables.tf`에 변수 정의를 추가하고, `terraform.tfvars`(또는 사용하는 tfvars 파일)에 값을 넣습니다.
4. 해당 스택 디렉터리에서 실행:
   ```bash
   terraform init -backend-config=...   # 필요 시 Backend 설정
   terraform plan -var-file=terraform.tfvars
   ```
5. plan 결과에서 **추가되는 리소스**만 있는지 확인한 뒤:
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```

### 6.3 리소스 변경 절차 (예: VM 크기만 변경)

1. **terraform-iac**에서 해당 리소스/모듈이 사용하는 **변수**가 정의된 위치를 찾습니다. (예: `terraform.tfvars` 또는 스택의 `variables.tf` + 기본값)
2. 해당 변수 값(예: `vm_size = "Standard_B2s"`)을 원하는 값으로 수정합니다.
3. 해당 스택 디렉터리에서:
   ```bash
   terraform plan -var-file=terraform.tfvars
   terraform apply -var-file=terraform.tfvars
   ```
4. plan에서 **in-place update** 또는 **replace** 중 어떤 일이 일어나는지 확인한 뒤 apply 합니다.

### 6.4 리소스 삭제 절차

1. 삭제할 **resource** 또는 **module** 블록을 해당 `.tf` 파일에서 **완전히 제거**합니다.
2. 해당 블록에서만 쓰이던 변수가 있다면, 사용처가 없어도 되므로 `variables.tf`/`terraform.tfvars`에서 정리해도 됩니다 (선택).
3. 해당 스택에서:
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```
   → plan 결과에 **destroy** 될 리소스가 나와야 합니다.
4. 확인 후:
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```
   → 삭제가 반영됩니다.

### 6.5 terraform-modules 쪽 수정 후 반영 방법

- **terraform-modules**에서 모듈 코드를 수정하고 **push**한 뒤, 그 모듈을 쓰는 **terraform-iac** 스택에서는:
  ```bash
  cd azure/dev/<해당 스택>
  terraform init -upgrade -backend-config=...   # 모듈 소스 갱신
  terraform plan -var-file=terraform.tfvars
  terraform apply -var-file=terraform.tfvars
  ```
- *upgrade: 캐시된 모듈을 무시하고, 지정한 source(git ref 등)의 최신 내용을 다시 가져옵니다.*

### 6.6 스택별로 자주 만지는 파일 (참고)

| 스택 | 주로 수정하는 파일 |
|------|---------------------|
| network | `main.tf` (hub_vnet, spoke_vnet 모듈 호출), `variables.tf`, `terraform.tfvars` |
| storage | `main.tf` (module "storage" 호출부는 `modules/dev/hub/monitoring-storage`), 변수/ tfvars |
| shared-services | `main.tf`, `variables.tf`, `terraform.tfvars` |
| apim | `main.tf`, `variables.tf`, `terraform.tfvars` |
| ai-services | `main.tf`, `variables.tf`, `terraform.tfvars` |
| compute | `main.tf`, `variables.tf`, `terraform.tfvars` |
| connectivity | `main.tf`, `variables.tf`, `terraform.tfvars` |

---

## 7. 용어 풀이 (엔지니어용 요약)

아래는 문서에서 사용한 어려운 용어를 한 곳에 모은 요약입니다.

| 용어 | 풀이 |
|------|------|
| **IaC (Infrastructure as Code)** | 인프라를 코드로 정의하고, 그 코드를 실행해 리소스를 만들고 바꾸는 방식. |
| **State** | Terraform이 "지금 관리 중인 리소스 목록과 속성"을 저장한 데이터. 보통 원격 Backend에 저장. |
| **Backend** | State 파일을 저장하는 위치(로컬 파일 또는 Azure Storage 등). |
| **Provider** | Terraform이 특정 클라우드(Azure, AWS 등)와 통신할 때 쓰는 플러그인. |
| **Module** | 여러 리소스를 묶어 재사용할 수 있게 만든 Terraform 코드 단위. |
| **remote_state** | 다른 스택(다른 디렉터리)의 State를 읽어, 그 스택의 output 값을 가져오는 데이터 소스. |
| **AVM (Azure Verified Modules)** | Microsoft가 검증·유지보수하는 Terraform용 Azure 공식 모듈 세트. |
| **래퍼(Wrapper)** | 외부 모듈(AVM 등)을 한 번 감싸서, 우리 프로젝트용 변수/출력 이름으로 다시 노출하는 작은 모듈. |
| **Registry** | Terraform 공식 모듈·프로바이더가 등록된 저장소(registry.terraform.io). |
| **스택(Stack)** | 이 문서에서는 `azure/dev/` 아래 한 디렉터리 단위. 각 스택은 별도 State를 가짐. |
| **ref** | Git 참조. `?ref=main`(브랜치), `?ref=v1.0.0`(태그) 등으로 모듈 버전 지정. |
| **HCL** | Terraform 설정 파일에 사용하는 HashiCorp의 설정 언어 문법. |

---

이 가이드는 **terraform-iac** 레포의 `docs/TERRAFORM_GUIDE.md` 에 있으며, **terraform-modules** 레포를 사용할 때는 [terraform-iac](https://github.com/kimchibee/terraform-iac) 의 이 문서와 README를 함께 참고하면 됩니다.
