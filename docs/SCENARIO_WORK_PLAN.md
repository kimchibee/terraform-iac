# 시나리오 검증 및 작업 계획 (IAM·AD·네트워크 통합)

이 문서는 다음 세 시나리오의 **관리 방법 체계**를 정리하고, 검증한 뒤 **Terraform 기반 작업 계획**을 단계별로 나눕니다.  
작업은 이 계획서의 단계를 하나씩 진행합니다.

---

## 1. 관리 방법 체계 요약

| 구분 | 시나리오 1 (그룹 기반 리소스 권한) | 시나리오 2 (리소스별 IAM) | 시나리오 3 (시큐리티 그룹·라우팅) |
|------|---------------------------|----------------------------|------------------------------------|
| **레이어** | Identity + IAM | IAM (리소스 단위) | 네트워크/보안 |
| **제어 방식** | AD 그룹별 IAM 할당 (관리자 그룹=전역, AI 개발자 그룹=AI 서비스만 등) | 리소스별로 identity→역할 매핑을 코드로 관리 | NSG + (선택) UDR로 “이 그룹이면 Key Vault 접근 가능” |
| **변경 시** | 그룹 멤버만 추가/삭제 → 해당 그룹에 부여된 리소스 권한 자동 반영 | Terraform에서 역할 할당 추가/변경/삭제 후 apply | NSG/라우팅 정책을 Terraform으로 관리, NSG 부여 시 자동 적용 |
| **단일 제어점** | 그룹별 멤버십 (관리자 그룹, AI 개발자 그룹 등) | “관리자 그룹” 멤버십 | Terraform 상태(코드) | “keyvault-sg” NSG + 라우팅 정의 |

**공통 원칙**

- **선언적·코드 우선**: 누가 무엇에 접근하는지는 Terraform(또는 AD 그룹 멤버십)으로 정의.
- **한 곳에서 정의**: (1) 그룹 기반 = 관리자 그룹(전역), AI 개발자 그룹(AI 서비스) 등 그룹별 scope, (2) 리소스별 권한 = RBAC 스택, (3) Key Vault 접근 경로 = NSG + 라우팅.
- **기존 스택과의 관계**: 시나리오 1·2는 **rbac** 스택 확장/분리, 시나리오 3은 **network** (및 필요 시 connectivity) 스택 확장.

---

## 2. 시나리오 검증

### 2.1 시나리오 1: 그룹 기반 리소스 권한 (관리자 그룹 + AI 개발자 그룹)

동일한 관리 체계를 **두 가지 그룹**에 적용합니다.

#### 1) 관리자 그룹

| 항목 | 내용 |
|------|------|
| **목표** | A 테넌트에 “관리자 그룹”을 두고, 해당 그룹 멤버만 추가/변경/삭제해도 그룹에 속한 사용자가 테넌트 리소스 관리 권한을 갖도록 함. |
| **전제** | 테넌트(A)가 하나로 정해져 있고, “관리자”는 그룹 멤버십으로만 정의됨. |
| **Azure 매핑** | Azure AD(Entra ID) 보안 그룹 + 구독(또는 RG) 범위 `azurerm_role_assignment`(principal = 그룹). |
| **검증 결과** | ✅ **적합.** 그룹에 역할을 부여하면 멤버 추가/제거만으로 권한이 따라감. Terraform은 “그룹 참조 + 구독(또는 RG) 범위 역할 할당”만 하면 됨. |
| **주의** | 그룹 생성/멤버십을 Terraform(azuread)으로 할지, AD 포털/다른 프로세스로 할지 정해야 함. |

#### 2) AI 개발자 그룹

| 항목 | 내용 |
|------|------|
| **목표** | A 테넌트에 "AI 개발자 그룹"을 두고, **같은 관리 체계**로 해당 그룹 멤버가 **AI 관련 서비스**(Azure OpenAI, AI Foundry, 관련 Storage/Key Vault 등)에 대한 접근 권한만 부여받도록 함. 멤버 추가/변경/삭제 시 해당 권한만 자동 반영. |
| **전제** | "AI 개발자"는 그룹 멤버십으로만 정의. 권한 범위는 AI 관련 리소스(또는 AI 전용 RG/리소스)로 제한. |
| **Azure 매핑** | Azure AD 보안 그룹 + **AI 관련 리소스 scope**에서 `azurerm_role_assignment`(principal = AI 개발자 그룹). scope = ai-services 스택 리소스(OpenAI, ML Workspace 등), 필요 시 관련 Storage/Key Vault. |
| **검증 결과** | ✅ **적합.** 관리자 그룹과 동일 패턴. 그룹 1개 + 해당 그룹에 AI 리소스 범위 역할만 할당하면, 멤버십 변경만으로 AI 서비스 접근 권한이 따라감. |
| **주의** | AI 관련 scope를 구독 전체가 아닌 리소스 그룹 또는 개별 리소스로 제한해 최소 권한 유지. |

---

### 2.2 시나리오 2: 리소스별 IAM 계정(역할) Terraform 관리

| 항목 | 내용 |
|------|------|
| **목표** | Key Vault 등 리소스 접근을 위해 IAM 권한이 필요하고, 리소스별로 상이한 “IAM 계정”(역할 부여 대상)을 Terraform으로 추가/변경/삭제하여 관리. |
| **전제** | “IAM 계정” = 역할을 부여받는 주체(Managed Identity, SP, 사용자, 그룹). Identity 생성은 AD/앱 등에서 하고, Terraform은 “어떤 리소스에 어떤 identity에게 어떤 역할을 줄지”만 관리. |
| **Azure 매핑** | `azurerm_role_assignment`를 리소스(Key Vault, Storage 등) 단위로 정의. 기존 rbac 스택과 동일 패턴. |
| **검증 결과** | ✅ **적합.** 현재 rbac 스택이 Monitoring VM에 대해 동일하게 역할 할당을 하고 있으므로, Key Vault·기타 리소스에 대한 역할 할당을 변수/리소스로 확장하면 됨. |
| **주의** | principal_id(identity)는 remote_state 또는 data로 참조하고, scope는 리소스 ID로 명시. |

---

### 2.3 시나리오 3: 시큐리티 그룹(NSG) 기반 Key Vault 라우팅/통신 제어

| 항목 | 내용 |
|------|------|
| **목표** | “keyvault-sg” 시큐리티 그룹을 부여받은 리소스만 Key Vault에 접근 가능하도록 하고, 해당 리소스에 대해 Key Vault 방향 양방향 라우팅(통신 제어)을 자동 부여. |
| **전제** | “시큐리티 그룹” = NSG(Network Security Group). 리소스 = 해당 NSG가 연결된 서브넷(또는 NIC). Key Vault는 Private Endpoint 사용 가정. |
| **Azure 매핑** | (1) NSG 규칙: Key Vault Private Endpoint 방향 트래픽 허용. (2) 필요 시 UDR: Key Vault FQDN/prefix → Private Endpoint 방향. |
| **검증 결과** | ✅ **적합.** NSG + UDR을 Terraform으로 정의하고, “keyvault-sg” NSG를 부여한 서브넷은 동일 규칙/라우팅을 공유. 레벨은 1·2와 다름(네트워크 레이어). |
| **주의** | Private Endpoint가 있는 VNet/서브넷과, 워크로드 서브넷이 같거나 피어링되어 있어야 함. 방화벽/NVA가 있으면 해당 경로 반영. |

---

## 3. 작업 계획 (단계별)

아래 단계를 **순서대로** 진행합니다. 각 단계 완료 후 다음 단계로 넘어갑니다.

---

### Phase A: 시나리오 1 — 그룹 기반 리소스 권한 (관리자 그룹 + AI 개발자 그룹)

| 단계 | 작업 내용 | 산출물 | 비고 |
|------|-----------|--------|------|
| **A-1** | 그룹용 Azure AD 연동 결정: Terraform `azuread` 사용 여부, 기존 그룹 사용 여부 (관리자 / AI 개발자 그룹 공통) | 결정 사항 (문서 또는 주석) | 기존 그룹이 있으면 data만 사용 가능 |
| **A-2** | **관리자 그룹**: 구독(또는 RG) 범위에서 “관리자 그룹”에 부여할 역할 정의 (예: Contributor, Owner) 및 변수화 | rbac 또는 새 스택에 변수/로컬 | 환경별로 다른 그룹 ID 허용 |
| **A-3** | **관리자 그룹**: Terraform에 `azurerm_role_assignment` 추가 — principal = 관리자 그룹, scope = 구독 또는 RG | main.tf (또는 전용 모듈) | rbac 스택 확장 또는 별도 스택 |
| **A-4** | **AI 개발자 그룹**: AI 관련 scope 정의 (ai-services RG 또는 OpenAI·AI Foundry 등 리소스 ID) 및 부여할 역할 정의 (예: Cognitive Services User 등) | 변수/로컬, remote_state로 ai_services 참조 | ai-services 스택 output 활용 |
| **A-5** | **AI 개발자 그룹**: Terraform에 `azurerm_role_assignment` 추가 — principal = AI 개발자 그룹, scope = AI 관련 리소스(RG 또는 개별 리소스) | main.tf | 관리자 그룹과 동일 패턴, scope만 AI로 제한 |
| **A-6** | README 및 변수 예시(terraform.tfvars.example)에 “관리자 그룹 / AI 개발자 그룹 ID 설정 방법” 및 멤버십 관리 방법 안내 | README, .example | AD 포털 vs Terraform 멤버십, 그룹별 역할 범위 설명 |

---

### Phase B: 시나리오 2 — 리소스별 IAM(역할) Terraform 관리 ✅ 완료

| 단계 | 작업 내용 | 산출물 | 비고 |
|------|-----------|--------|------|
| **B-1** | Key Vault 외 추가 대상 리소스 목록 정리 (Storage, AI Services 등) 및 역할 정의 (역할 이름, scope) | 문서 또는 variables.tf 주석 | 기존 rbac의 Key Vault/Storage 패턴 재사용 |
| **B-2** | “IAM 계정”(principal) 목록을 변수/구조화로 받도록 설계 (identity별, 리소스별 역할 매핑) | variables.tf, tfvars.example | for_each 또는 count |
| **B-3** | rbac 스택에 Key Vault/기타 리소스에 대한 역할 할당을 변수 기반으로 추가 (기존 리소스 유지) | rbac/main.tf, variables.tf | remote_state로 리소스 ID·principal_id 참조 |
| **B-4** | 역할 할당 추가/변경/삭제 절차를 rbac README에 반영 (공통 절차와 동일: 변수·tfvars 수정 후 루트에서 plan/apply) | rbac/README.md | |

---

### Phase C: 시나리오 3 — 시큐리티 그룹(NSG) 기반 Key Vault 라우팅 ✅ 완료

| 단계 | 작업 내용 | 산출물 | 비고 |
|------|-----------|--------|------|
| **C-1** | Key Vault Private Endpoint 위치 확인 (어느 VNet/서브넷인지). 현재 network/storage 구조에서 PE 존재 여부 확인 | 확인 결과 (문서 또는 주석) | ✅ storage: monitoring-storage(Git)가 Hub **pep-snet** 사용 |
| **C-2** | “keyvault-sg” NSG 규칙 설계: Key Vault PE 방향 아웃바운드(및 필요 시 인바운드) 허용 규칙 | 규칙 명세 (문서) | 아웃바운드: Destination=AzureKeyVault, Port=443, Allow |
| **C-3** | network 스택에 keyvault-sg NSG 리소스 및 규칙 추가 (또는 기존 NSG에 규칙 추가) | network/keyvault-sg/ 모듈 | NSG 생성 + 기존 NSG에 규칙 추가 지원 |
| **C-4** | Key Vault 접근이 필요한 서브넷에 UDR 필요 여부 판단 후, 필요 시 route table + 서브넷 연결 | README 문서 | PE가 동일 VNet(Hub)이면 UDR 불필요; VNet 피어링으로 라우팅 |
| **C-5** | “keyvault-sg를 부여받은 리소스” 정의: 어떤 서브넷에 이 NSG를 붙일지 변수화 및 README 안내 | variables.tf, README | hub_subnet_names_for_keyvault_sg, nsg_ids_add_keyvault_rule |

---

### Phase D: 통합 및 문서

| 단계 | 작업 내용 | 산출물 | 비고 |
|------|-----------|--------|------|
| **D-1** | 세 시나리오가 공존할 때 배포 순서 정리 (network → storage → … → rbac → connectivity 등) 및 의존성 명시 | README 또는 docs 업데이트 | |
| **D-2** | 이 작업 계획서(SCENARIO_WORK_PLAN.md)를 “진행 완료” 상태로 갱신하고, 각 Phase별 완료 체크 표시 | SCENARIO_WORK_PLAN.md | |

---

## 4. 진행 방식

- **한 번에 한 Phase** 또는 **한 번에 한 단계**씩 진행합니다.
- 각 단계 완료 시 이 문서의 해당 단계에 완료 표시(예: ✅)를 남기고, 다음 단계를 진행합니다.
- 코드/파일 변경이 필요한 단계는 구체적인 수정안을 제안한 뒤 적용합니다.

**다음 진행**: Phase A-1부터 시작합니다. (관리자 그룹용 Azure AD 연동 방식 결정)
