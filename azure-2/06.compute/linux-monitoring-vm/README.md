# linux-monitoring-vm (모듈)

compute **루트**에서 `module { source = "./linux-monitoring-vm"; ... }` 로 호출하는 **모듈**입니다.  
단독으로 `terraform apply` 하지 않고, **compute 루트**에서만 배포합니다.

---

## 디렉터리·파일 역할

| 파일 | 역할 |
|------|------|
| `main.tf` | Git 모듈 `virtual-machine` 호출, NIC·OS Disk·(선택) 확장, ASG 연결 |
| `variables.tf` | 입력 변수·기본값(이 폴더에서 관리하는 리소스 스펙) |
| `versions.tf` | Terraform / provider 버전 제약 |

---

## 배포 방법(수정 위치)

- **plan/apply는 항상 `azure/dev/06.compute` 루트**에서 실행합니다.
- **신규 Linux VM 추가 시**: 이 폴더를 통째로 복사(예: `linux-app-01`) → **복사한 폴더의 `variables.tf` 기본값만** 수정 → compute 루트 `main.tf`에 `module` 블록만 추가.

---

## 변수: 누가 넣는지 / 의미

### 루트(`06.compute`)에서 전달하는 값(컨텍스트)

| 변수 | 의미 |
|------|------|
| `name_prefix` | `project_name` 등에서 만든 리소스 이름 접두사 |
| `resource_group_name` | VM이 속할 Hub RG 이름(network state) |
| `subnet_id` | VM이 붙을 서브넷 ID(보통 Monitoring-VM-Subnet) |
| `location` | 리전 |
| `tags` | 태그 맵 |
| `application_security_group_ids` | NIC에 연결할 ASG 리소스 ID 목록(루트에서 network state 기반으로 계산) |

### 이 폴더 `variables.tf` 기본값으로 관리(복제 시 여기만 수정)

| 변수 | 의미 |
|------|------|
| `vm_name_suffix` | VM 이름 접미사. 최종 이름은 `{name_prefix}-{vm_name_suffix}` 형태로 조합 |
| `vm_size` | Azure VM SKU(예: `Standard_D2s_v3`) |
| `admin_username` | Linux 관리자 계정 이름 |
| `ssh_private_key_filename` | SSH 개인키 파일명. **compute 루트 디렉터리 기준 경로**(저장소에 커밋하지 않음) |
| `enable_vm` | `false`로 두면 해당 VM 리소스 생성을 건너뛸 수 있음(모듈 구현에 따름) |
| `vm_extensions` | VM 확장(예: Azure Monitor Agent) 블록 목록 |

---

## 관련 문서

- 전체 흐름·ASG·신규 VM 절차: 상위 디렉터리 [`../README.md`](../README.md)
