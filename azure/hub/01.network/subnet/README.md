# Subnet 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/subnet` 리소스의 **생성/변경/삭제** 절차입니다.

대표 리프:
- `hub-appgateway-subnet`
- `hub-azurefirewall-subnet`
- `hub-azurefirewall-management-subnet`
- `hub-dnsresolver-inbound-subnet`
- `hub-gateway-subnet`
- `hub-monitoring-vm-subnet`
- `hub-pep-subnet`
- `spoke-apim-subnet`
- `spoke-pep-subnet`

---

## 0) 사전 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create)

예시: Hub Monitoring VM subnet

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/subnet/hub-monitoring-vm-subnet
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

반복 적용:
- 같은 방식으로 각 리프 디렉토리에서 수행

---

## 2) 변경(Update)

예: CIDR 변경, 서비스 엔드포인트/위임 변경, NSG 연동 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

주의:
- 이미 리소스가 붙어있는 subnet의 CIDR 변경은 교체(recreate)가 발생할 수 있습니다.

---

## 3) 삭제(Delete)

삭제 전 확인:
- VM/PE/Gateway 등 subnet 사용 리소스를 먼저 제거해야 할 수 있습니다.

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

---

## 4) 검증 명령

```bash
terraform state list
az network vnet subnet list -g "<RG_NAME>" --vnet-name "<VNET_NAME>" -o table
```
