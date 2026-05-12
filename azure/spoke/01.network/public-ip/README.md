# Public IP 리소스 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/public-ip` 리소스를 **생성/변경/삭제**하는 표준 절차입니다.

현재 리프:
- `hub-vpn-gateway`

---

## 0) 사전 확인

```bash
az login
az account show -o table
terraform version
```

---

## 1) 작업 디렉토리 이동

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/public-ip/hub-vpn-gateway
```

---

## 2) 생성(Create)

1. 값 점검 (`terraform.tfvars`)
2. 계획 확인
3. 적용

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

---

## 3) 변경(Update)

예: SKU, 이름 접두사, 태그 변경

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

변경 후 검증:

```bash
terraform plan
terraform state list
```

---

## 4) 삭제(Delete)

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform plan -destroy
terraform destroy -auto-approve
```

삭제 후:

```bash
terraform plan
```

---

## 5) 자주 발생하는 이슈

- backend 접근 실패: Hub 구독으로 다시 전환 후 재실행
- 이미 존재 리소스 충돌: `terraform import` 후 `plan` 재확인
