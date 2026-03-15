# 다른 AI에게 요청할 때 사용하는 컨텍스트 프롬프트

아래 블록을 **복사해서** 채팅 맨 앞에 붙여 넣고, 그 다음에 하고 싶은 작업을 적어 주세요.

---

## 프롬프트 (복사용)

```
[프로젝트 컨텍스트]

이 프로젝트는 Terraform으로 Azure Hub-Spoke 인프라를 관리하는 **terraform-iac** 레포입니다.

**전체 구조**
- 스택별로 디렉터리가 나뉘어 있고, 각 스택은 **독립 State** (azure/dev/<스택명>/terraform.tfstate) 를 가짐.
- 공통 모듈은 **terraform-modules** Git 레포만 참조: source = "git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=main"
- 배포 순서: Bootstrap → network → storage → shared-services → apim → ai-services → compute → rbac → connectivity
- Backend: Azure Storage, init 시 -backend-config=backend.hcl 사용. backend.hcl은 scripts/generate-backend-hcl.sh 로 생성.

**스택 공통 구조 (compute와 동일 패턴 적용)**
- 각 스택은 **루트에서만** terraform plan/apply 실행. State는 스택당 **1개** (azure/dev/<스택명>/terraform.tfstate).
- **하위 디렉터리는 모듈**로만 사용: backend.tf, provider.tf, data.terraform_remote_state 없음. 루트에서 remote_state 조회 후 변수로 전달.
- **신규 리소스 추가 시**: 해당 스택의 예시 디렉터리 복사 → 루트 main.tf에 module 블록 추가 → 루트 variables.tf / terraform.tfvars에 변수 추가 → 해당 스택 루트에서 plan/apply.

**스택별 하위 모듈**
- **network**: hub-vnet/, spoke-vnet/
- **storage**: monitoring-storage/
- **shared-services**: log-analytics-workspace/, shared-services/
- **compute**: linux-monitoring-vm/, windows-example/
- **apim**, **ai-services**, **rbac**, **connectivity**: 루트 main.tf 하나에서 data + module/resource 호출 (하위 모듈 디렉터리 없음).

- rbac와 storage는 compute 루트 state 참조 (key = "azure/dev/compute/terraform.tfstate"). output "monitoring_vm_identity_principal_id" 가 Linux Monitoring VM Identity.

**참고할 문서**
- 루트: README.md (배포 순서, 스택 구조)
- compute: azure/dev/compute/README.md | network: azure/dev/network/README.md | storage: azure/dev/storage/README.md | shared-services: azure/dev/shared-services/README.md
```

---

## 사용 예시

- **예시 1 (신규 Linux VM 추가)**  
  위 프롬프트 붙인 뒤:  
  `linux-app-02 라는 새 Linux VM 스택을 추가해줘. vm_size는 Standard_B2ms, vm_name은 app-02로.`

- **예시 2 (다른 스택 수정)**  
  위 프롬프트 붙인 뒤:  
  `network 스택에서 Hub VNet 주소 대역을 10.0.0.0/16 에서 10.1.0.0/16 으로 변경하는 방법 알려줘.`

- **예시 3 (Compute만 설명)**  
  위 프롬프트 중 **Compute 스택** 부분만 복사한 뒤:  
  `compute에 Windows VM 하나 더 추가하고, 변수명은 windows_jumpbox_* 로 통일해줘.`
