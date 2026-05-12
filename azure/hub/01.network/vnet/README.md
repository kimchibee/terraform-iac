# VNet 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/vnet` 리소스의 **생성/변경/삭제** 절차입니다.

현재 리프:
- `hub-vnet`
- `spoke-vnet`

---

## 0) 사전 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create) 권장 순서

1. `hub-vnet`
2. `spoke-vnet`

### 1-1) Hub VNet

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/vnet/hub-vnet
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

### 1-2) Spoke VNet

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/vnet/spoke-vnet
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

---

## 2) 변경(Update)

예: 주소 공간(address space), DNS 설정, 태그 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

주의:
- 주소 공간 변경은 피어링/라우팅/서브넷에 연쇄 영향이 있습니다.

---

## 3) 삭제(Delete)

삭제 전:
- VNet 내 subnet/peering/gateway/PE 사용 리소스가 없어야 합니다.

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

---

## 4) 검증

```bash
terraform state list
az network vnet list -g "<RG_NAME>" -o table
```
