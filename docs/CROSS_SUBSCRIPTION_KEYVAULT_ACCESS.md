# 다른 구독(Spoke) VM이 Hub Key Vault PE에 접근할 때 — 네트워크 방화벽 & IAM 할당

## 시나리오

- **Key Vault**는 Hub 구독에 있고, **Private Endpoint(PE)**는 Hub VNet의 **pep-snet**에 연결됨.
- **VM**은 **다른 구독(Spoke)** 의 **Spoke VNet**에서 생성됨.
- 이 VM이 Hub의 Key Vault(PE 경유)에 접근하려면 **네트워크 방화벽**과 **IAM 권한** 둘 다 필요함.

---

## 1. 네트워크 방화벽 (PE까지 트래픽 허용)

### 누가 무엇을 하냐

- **정책 위치:** Hub의 **Key Vault PE가 붙은 서브넷(pep-snet)의 NSG**.
- **규칙:** 인바운드 1개 — 소스 = **keyvault-clients ASG**, 포트 443.
- **ASG:** Network 스택에서 `enable_pe_inbound_from_asg = true` 로 생성한 `keyvault_clients_asg`.

### Spoke VM에 적용하는 방법

- **Spoke VM의 NIC**에 위 ASG(`keyvault_clients_asg_id`)를 **붙이면** 됨.
- ASG는 Hub 구독에서 만들어지지만, **동일 테넌트**라면 Spoke 구독의 NIC에 그대로 연결 가능함.
- Compute 스택에서 Spoke VM을 만들 때:
  - **subnet_id** = Spoke 서브넷 ID (network remote_state의 `spoke_subnet_ids["원하는서브넷"]` 등).
  - **application_security_group_ids** 에 `keyvault_clients_asg_id` 포함 (또는 `application_security_group_keys = ["keyvault_clients"]` 로 키만 지정).
- 그러면 Spoke VM → (VNet 피어링) → Hub pep-snet(PE) 구간이 PE NSG 인바운드 1개 정책으로 허용됨.

**요약:** Spoke VM이어도 **동일하게 keyvault_clients ASG를 NIC에 연결**하면, 네트워크 방화벽은 한 정책으로 할당됨. 구독이 달라도 절차는 같음.

---

## 2. IAM 권한 (Key Vault 리소스에 대한 RBAC)

### 누가 무엇을 하냐

- **역할 할당 주체:** RBAC 스택.
- **대상:** Key Vault 리소스(scope = storage 스택의 Key Vault ID).
- **principal:** Spoke VM의 **Managed Identity** `principal_id`.

### Spoke VM에 적용하는 방법

1. **Compute 스택**  
   - Spoke VM을 **Managed Identity 사용**으로 생성.  
   - 해당 VM의 `identity_principal_id` 를 **output**으로 내보냄 (예: `spoke_linux_vm_identity_principal_id`).

2. **RBAC 스택**  
   - `terraform_remote_state` 로 compute 스택 state를 읽어, 위 **principal_id**를 참조.  
   - **iam_role_assignments** 에 다음 한 건 추가:
     - `principal_id` = Spoke VM의 Managed Identity principal_id (compute output에서 참조).
     - `scope_ref` = `"storage_key_vault_id"` (Hub Key Vault).
     - `role_definition_name` = `"Key Vault Secrets User"` (또는 필요한 역할).
     - `use_spoke_provider` = **false** (역할 할당의 **scope**가 Key Vault이므로 Hub 구독에서 할당).

3. RBAC 스택에서 `terraform apply` 하면, 해당 Spoke VM Identity에 Hub Key Vault에 대한 역할이 부여됨.

**요약:** Spoke VM의 **Identity**에 대해, **RBAC 스택**에서 Hub Key Vault(scope_ref: `storage_key_vault_id`)에 역할을 할당함. 구독이 다른 것은 principal_id만 맞으면 되고, scope가 Hub 리소스이므로 `use_spoke_provider = false` 로 두면 됨.

---

## 3. 절차 요약 (Spoke VM 한 대 기준)

| 순서 | 스택      | 작업 |
|------|-----------|------|
| 1    | **Network** | `enable_keyvault_sg`, `enable_pe_inbound_from_asg = true` 적용 후 apply. keyvault_clients ASG 생성·PE NSG 인바운드 1개 확정. |
| 2    | **Compute** | Spoke 서브넷에 VM 생성 (Managed Identity 사용). NIC에 `application_security_group_keys = ["keyvault_clients"]` (또는 keyvault_clients_asg_id) 연결. 해당 VM의 `identity_principal_id` output 추가. |
| 3    | **RBAC**    | compute remote_state에서 Spoke VM의 principal_id 참조. `iam_role_assignments`에 principal_id, scope_ref=`storage_key_vault_id`, role=`Key Vault Secrets User`, use_spoke_provider=false 로 추가 후 apply. |

이렇게 하면 **네트워크 방화벽(PE 인바운드 정책)** 과 **IAM(Key Vault 역할 할당)** 이 모두 Spoke 구독 VM에 대해 할당됨.
