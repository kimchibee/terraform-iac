# Resource Group 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/resource-group` 리소스의 **생성/변경/삭제** 절차입니다.

현재 리프:
- `hub-rg`
- `spoke-rg`

---

## 0) 공통 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create)

### 1-1) Hub RG

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/resource-group/hub-rg
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

### 1-2) Spoke RG

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/resource-group/spoke-rg
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

참고: backend state 저장소가 Hub 구독이면 `init/plan/apply` 전 Hub 구독 컨텍스트를 사용합니다.

---

## 2) 변경(Update)

예: 이름 규칙, 위치, 태그 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

---

## 3) 삭제(Delete)

삭제 전 의존성 확인:
- 해당 RG를 참조하는 하위 리소스가 있으면 먼저 삭제해야 합니다.

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

---

## 4) 빠른 점검 명령

```bash
terraform state list
az group show -n "<RG_NAME>" -o table
```
