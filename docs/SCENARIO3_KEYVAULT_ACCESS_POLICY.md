# 시나리오 3: Key Vault 접근 정책 — 한 정책으로 여러 대상 적용

## 질문 요약

- **타겟:** Monitoring VM, Spoke VNet 내 Linux 서버  
- **방화벽 정책:** 인바운드 — 소스 = 해당 시큐리티 그룹, 포트 443  
- **궁금점:** 이 정책 **하나**로 Monitoring VM과 Spoke Linux 서버 둘 다 제어 가능한가?  
  - 같은 VNet이면 가능할 것 같고, **다른 VNet(Hub vs Spoke)**인 경우는 어떻게 해야 하나?

---

## 결론

| 구분 | 한 정책으로 가능? | 방법 |
|------|-------------------|------|
| **같은 VNet** | ✅ 가능 | 해당 서브넷 NSG에 아웃바운드 1개(Allow AzureKeyVault:443) → 같은 서브넷의 모든 VM에 동일 적용 |
| **다른 VNet (Hub + Spoke)** | ✅ 가능 | **Key Vault PE 쪽**에서 **인바운드 1개** + **Application Security Group(ASG)** 사용. 소스 = ASG, 포트 443. Monitoring VM·Spoke Linux NIC에 같은 ASG만 붙이면 한 정책으로 둘 다 허용 |

---

## 1. 같은 VNet인 경우

- Monitoring VM과 Linux 서버가 **같은 서브넷**이면, 그 서브넷에 붙은 NSG에 **아웃바운드 규칙 1개**만 두면 됨.  
  - 예: `Allow AzureKeyVault:443`  
- 따라서 **정책 1개(규칙 1개)**로 두 VM 모두 Key Vault 접근 가능.

---

## 2. 다른 VNet인 경우 (Hub Monitoring VM + Spoke Linux)

두 가지 방식이 있다.

### 방식 A: 클라이언트(VM) 쪽 아웃바운드 규칙을 각각 적용 (현재 구현)

- **Hub** Monitoring VM 서브넷 NSG: 아웃바운드 1개 (Allow AzureKeyVault:443)  
- **Spoke** Linux 서버 서브넷 NSG: 아웃바운드 1개 (동일 규칙)  
- **정책 정의**는 1종류지만, **적용 위치**가 2곳(NSG 2개).  
- Spoke NSG를 keyvault-sg 모듈에서 지원하려면 Spoke NSG ID/이름을 변수로 받아 동일 규칙을 추가하면 됨.

### 방식 B: PE 쪽 인바운드 1개 + Application Security Group (권장 — “한 정책” 구현)

- **정책 위치:** Key Vault **Private Endpoint가 붙은 서브넷(pep-snet)의 NSG**  
- **규칙 1개:** **인바운드**, 소스 = **Application Security Group(ASG)**, 목적지 포트 = 443  
- **ASG 1개** (예: `keyvault-clients-asg`)를 만들고,  
  - Monitoring VM NIC  
  - Spoke Linux 서버 NIC  
  에 **같은 ASG**를 연결.  
- 그러면 **인바운드 정책 1개(소스 = 해당 시큐리티 그룹 + 443)**만으로,  
  - Hub의 Monitoring VM  
  - Spoke의 Linux 서버  
  둘 다 Key Vault 접근 가능. (VNet이 달라도 한 정책으로 처리)

요약:

- **타겟:** Monitoring VM + Spoke Linux  
- **방화벽 정책:** 인바운드, 소스 = “해당 시큐리티 그룹”, 443  
- **Azure 구현:**  
  - “시큐리티 그룹” = **Application Security Group(ASG)**  
  - **적용 위치** = Key Vault PE가 붙은 서브넷(pep-snet)의 NSG  
  - 정책 1개로 같은 VNet/다른 VNet 모두 처리 가능.

---

## 3. 방식 B 구현 요약 (Terraform)

1. **Network 스택 (keyvault-sg)**  
   - ASG 리소스 1개 생성 (예: `keyvault-clients-asg`).  
   - Key Vault PE 서브넷용 NSG(pep NSG)에 **인바운드 규칙 1개** 추가:  
     - `source_application_security_group_ids = [ASG ID]`  
     - `destination_port_range = "443"`  
   - ASG ID를 output으로 내보냄.

2. **Compute 스택 (Monitoring VM, Spoke Linux 등)**  
   - VM NIC에 위 ASG를 연결 (`application_security_group_ids = [network 스택에서 받은 ASG ID]`).  
   - Key Vault 접근이 필요한 VM만 이 ASG를 붙이면, PE 쪽 인바운드 1개 정책으로 모두 허용됨.

이렇게 하면 “Monitoring VM + Spoke Linux에 정책을 내릴 때 저 정책 하나로 구현 가능한가?” → **가능**하고, **다른 VNet인 경우**는 **PE 쪽 인바운드 + ASG**로 한 정책으로 처리하면 됨.
