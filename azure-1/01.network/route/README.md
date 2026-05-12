# Route 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/route`의 UDR 리소스를 **생성/변경/삭제**하는 절차입니다.

현재 리프:
- `hub-route-default`
- `spoke-route-default`

---

## 0) 사전 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create)

권장 순서:
1. `hub-route-default`
2. `spoke-route-default`

### 1-1) Hub route

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/route/hub-route-default
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

### 1-2) Spoke route

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/route/spoke-route-default
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

---

## 2) 변경(Update)

예: next hop 타입/IP, 목적지 prefix 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

---

## 3) 삭제(Delete)

주의:
- 라우트 삭제 시 트래픽 경로가 즉시 바뀔 수 있으므로 유지보수 창에서 실행하세요.

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

---

## 4) 검증

```bash
terraform state list
az network route-table list -g "<RG_NAME>" -o table
```
