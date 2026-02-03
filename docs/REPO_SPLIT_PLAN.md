# 레포지토리 분리 계획 (Archive → terraform-modules / terraform-iac → 별도 레포)

## 1. 목표

- **현재 레포**: 한 레포에 루트 + modules + terraform_modules + terraform_iac 혼재
- **최종**:  
  - **terraform-modules 레포**: 공통 모듈만 (라이브러리, Git Tag 버전 관리)  
  - **terraform-iac 레포**: 배포 루트만 (Provider, Backend, 환경별 코드, `terraform plan/apply`)

---

## 2. 단계 요약

| 단계 | 작업 | 비고 |
|------|------|------|
| 0 | **terraform-archive 레포 연동** | 원격 `archive` 추가 → 아카이브 브랜치 푸시 ([kimchibee/terraform-archive](https://github.com/kimchibee/terraform-archive)) |
| 1 | **archive 브랜치 생성·푸시** | 현재 전체 코드를 terraform-archive 레포에 보관 (백업 + 참조용) |
| 2 | **terraform-modules 브랜치** | (현재 레포에서) terraform_modules/ 내용만 유지, 나머지 제거 |
| 3 | **terraform-iac 브랜치** | terraform_iac/ + 루트 설정(backend, provider, env)만 유지, 모듈은 **다른 레포 참조**로 변경 |
| 4 | **분류 작업** | 각 브랜치에 맞게 파일 이동·정리 (모듈 소스 경로를 레포 URL + ref 로) |
| 5 | **별도 레포로 이전** | terraform-modules 브랜치 → 새 레포 A, terraform-iac 브랜치 → 새 레포 B (또는 현재 레포를 iac로 사용) |

---

## 3. 상세 작업

### 3.1 archive 브랜치 → terraform-archive 레포에 푸시

**아카이브 저장소**: [https://github.com/kimchibee/terraform-archive](https://github.com/kimchibee/terraform-archive)

현재 작업 디렉터리(terraform-config)에서 아래 순서로 실행합니다.

```bash
# 1) 아카이브용 원격 추가
git remote add archive https://github.com/kimchibee/terraform-archive.git

# 2) 현재 상태 커밋이 없다면 스테이징 후 커밋
git status
git add .
git commit -m "chore: archive state before repo split"   # 변경이 있을 때만

# 3) 아카이브 브랜치 생성 (현재 브랜치 기준)
git checkout -b archive/pre-split

# 4) terraform-archive 레포로 푸시 (해당 브랜치를 archive 레포의 main에 올리려면)
git push archive archive/pre-split:main
```

- **main 대신 브랜치명 그대로 올리려면**: `git push archive archive/pre-split:archive/pre-split`
- **포함**: 현재 레포의 전체 구조 (루트, modules/, terraform_modules/, terraform_iac/, docs 등)
- **용도**: 분리 전 상태를 terraform-archive 레포에 보관, 이후 “예전 구조” 참조용

**현재 폴더가 아직 Git 저장소가 아닌 경우** (예: 압축 해제본 또는 복사본):

```bash
cd /path/to/terraform-config
git init
git add .
git commit -m "chore: archive state before repo split"
git remote add archive https://github.com/kimchibee/terraform-archive.git
git branch -M archive/pre-split
git push -u archive archive/pre-split:main
```

이후 terraform-modules / terraform-iac 작업은 이 폴더에서 `git checkout -b terraform-modules` 등으로 새 브랜치를 만들어 진행하거나, 기존 레포를 clone한 뒤 그 레포에서 브랜치 작업을 진행하면 됩니다.

---

### 3.2 terraform-modules 브랜치

- **생성**: `archive/pre-split` 또는 `main`에서 분기  
  ```bash
  git checkout -b terraform-modules
  ```
- **유지할 것**  
  - `terraform_modules/` 전체 (resource-group, vnet, storage-account, key-vault, private-endpoint, README, VERSIONING, MODULE_REVIEW 등)  
  - 루트: `.gitignore`, 필요 시 `README.md` (모듈 레포용)
- **제거할 것**  
  - 루트 `main.tf`, `variables.tf`, `provider.tf`, `terraform.tf`, `modules/`, `terraform_iac/`, `config/`, 기타 배포용/문서만 있는 파일
- **결과**: 이 브랜치에는 **공통 모듈만** 있어서, 나중에 이 브랜치를 **terraform-modules 전용 새 레포**로 push 가능

---

### 3.3 terraform-iac 브랜치

- **생성**: `archive/pre-split` 또는 `main`에서 분기  
  ```bash
  git checkout -b terraform-iac
  ```
- **유지할 것**  
  - `terraform_iac/` (환경별 디렉터리, 루트 모듈 호출 등)  
  - 루트: `terraform.tf`(backend, required_providers), `provider.tf`, `variables.tf`, `*.tfvars.example`, `.gitignore` 등 **배포 실행에 필요한 것만**
- **모듈 참조 방식**  
  - 기존 `source = "./terraform_modules/..."` 또는 `../terraform_modules/...`  
  → **다른 레포** 참조로 변경  
  ```hcl
  source = "git::https://github.com/<org>/terraform-modules.git//resource-group?ref=v1.0.0"
  source = "git::https://github.com/<org>/terraform-modules.git//vnet?ref=v1.0.0"
  # ...
  ```
- **제거할 것**  
  - `terraform_modules/` 디렉터리 전체 (모듈은 별도 레포에서 관리)  
  - 필요 없다고 판단되는 레거시 `modules/`, 중복 문서 등
- **결과**: 이 브랜치에는 **배포 루트만** 있고, 모듈은 **terraform-modules 레포의 태그(ref)** 로만 참조

---

### 3.4 분류 작업 체크리스트

- [ ] archive 브랜치 푸시 완료
- [ ] terraform-modules 브랜치: terraform_modules/ 외 삭제, 루트 정리
- [ ] terraform-iac 브랜치: terraform_iac/ + 루트 배포 설정만 유지, 모듈 소스를 **git::https://github.com/.../terraform-modules.git?ref=...** 로 변경
- [ ] terraform-modules 브랜치에서 `terraform validate` (각 모듈)
- [ ] terraform-iac 브랜치에서 `terraform init` + `terraform validate` (모듈 소스가 아직 같은 레포면 상대 경로로 먼저 검증 후, 레포 분리 후 URL로 교체)

---

### 3.5 별도 레포로 이전

**옵션 A: 새 레포 두 개 생성**

1. **terraform-modules 레포** ([https://github.com/kimchibee/terraform-modules](https://github.com/kimchibee/terraform-modules))  
   - 로컬에서 (terraform-config 폴더 기준):
     ```bash
     git remote add modules https://github.com/kimchibee/terraform-modules.git
     git checkout terraform-modules
     git push modules terraform-modules:main
     ```
   - terraform-modules 레포가 비어 있으면 위 push로 main에 공통 모듈이 올라감.  
   - 이후 모듈 레포는 `main` + Git Tag(v1.0.0 등)로 버전 관리.

2. **terraform-iac 레포** (별도 레포 생성 후)  
   - 로컬에서:
     ```bash
     git remote add iac https://github.com/kimchibee/terraform-iac.git
     git checkout terraform-iac
     git push iac terraform-iac:main
     ```
   - terraform-iac의 `main.tf` 등에서 모듈 소스는 `git::https://github.com/kimchibee/terraform-modules.git//terraform_modules/모듈명?ref=v1.0.0` 형태로 참조.

**옵션 B: 현재 레포를 terraform-iac으로 사용**

1. 현재 레포를 “terraform-iac” 용도로 사용한다고 정한 뒤  
2. `main`을 terraform-iac 브랜치 내용으로 교체 (force push 또는 main에 merge)  
3. **terraform-modules만** 새 레포로 만들고, terraform-modules 브랜치를 그 레포의 main으로 push  
4. terraform-iac(현재 레포)에서는 위처럼 `terraform-modules` 레포 URL + ref 로 참조

---

## 4. 분리 후 구조

```
[GitHub]
├── <org>/terraform-config (또는 유지)
│   └── archive/pre-split   ← 과거 전체 백업 (필요 시 참조)
│
├── <org>/terraform-modules  ← 새 레포 (또는 기존 레포 중 하나)
│   └── main (+ tags: v1.0.0, v1.1.0, ...)
│       ├── resource-group/
│       ├── vnet/
│       ├── storage-account/
│       ├── key-vault/
│       ├── private-endpoint/
│       ├── README.md
│       └── VERSIONING.md
│
└── <org>/terraform-iac     ← 새 레포 (또는 현재 레포를 이 용도로)
    └── main
        ├── environments/    (또는 루트에 직접)
        │   ├── dev/
        │   ├── stage/
        │   └── prod/
        ├── terraform.tf     (backend, required_providers)
        ├── provider.tf
        ├── variables.tf
        └── ... (모듈 호출은 source = "git::...terraform-modules.git//...?ref=v1.0.0")
```

---

## 5. 정리

- **archive 브랜치**로 현재 상태 적재 → **terraform-modules / terraform-iac 두 브랜치**에서 분류 작업 → **각 브랜치를 서로 다른 레포로 옮기는** 흐름은 타당하고, 일반적으로 쓰는 패턴과도 잘 맞습니다.
- 모듈은 **태그(ref) 기반**으로만 참조하면, terraform-modules 레포와 terraform-iac 레포를 독립적으로 버전 관리·배포할 수 있습니다.

이 문서는 `docs/REPO_SPLIT_PLAN.md` 로 두었습니다. 단계 진행 시 이 파일을 기준으로 체크하면서 진행하시면 됩니다.
