# windows-example (모듈)

compute **루트**에서 `module { source = "./windows-example"; ... }` 로 호출하는 **모듈**입니다.  
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
- **신규 Windows VM 추가 시**: 이 폴더를 통째로 복사 → **복사한 폴더의 `variables.tf` 기본값** 수정 → 루트 `main.tf`에 `module` 추가 → **루트 `variables.tf` / `terraform.tfvars`에 해당 VM용 `admin_password` 변수 1개** 추가(비밀번호는 루트에서만 관리).

---

## 변수: 누가 넣는지 / 의미

### 루트에서 전달하는 값

| 변수 | 의미 |
|------|------|
| `name_prefix` | 리소스 이름 접두사 |
| `resource_group_name`, `subnet_id`, `location`, `tags` | RG·서브넷·리전·태그 |
| `application_security_group_ids` | NIC에 연결할 ASG ID 목록 |
| `admin_password` | Windows 관리자 비밀번호(**sensitive**). 루트 `terraform.tfvars`에만 기입 |

### 이 폴더 `variables.tf` 기본값으로 관리(복제 시 여기만 수정)

| 변수 | 의미 |
|------|------|
| `vm_name_suffix` | Azure VM **리소스 이름** 접미사 |
| `vm_computer_name_suffix` | OS **컴퓨터 이름(호스트명)** 접미사. Windows는 **15자 제한**이 있어 짧게 두는 경우가 많음 |
| `vm_size` | VM SKU |
| `admin_username` | Windows 관리자 계정 이름 |
| `enable_vm` | VM 생성 여부 |
| `vm_extensions` | VM 확장(예: Azure Monitor Agent) 목록 |

---

## 관련 문서

- 전체 흐름·ASG·신규 VM 절차: 상위 디렉터리 [`../README.md`](../README.md)
