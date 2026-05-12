# Virtual Network Gateway 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/virtual-network-gateway` 리소스의 **생성/변경/삭제** 절차입니다.

현재 리프:
- `hub-vpn-gateway`

---

## 0) 사전 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create)

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/virtual-network-gateway/hub-vpn-gateway
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

주의:
- VPN Gateway는 생성/변경 시간이 길 수 있습니다.

---

## 2) 변경(Update)

예: SKU, 활성-활성 설정, BGP/태그 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

---

## 3) 삭제(Delete)

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

주의:
- 삭제 시 연결(온프렘/VPN 터널)이 즉시 중단됩니다.

---

## 4) 검증

```bash
terraform state list
az network vnet-gateway show -g "<HUB_RG>" -n "<GATEWAY_NAME>" -o table
```
