# Security Group 가이드 (Bash, 복사/붙여넣기)

이 문서는 `01.network/security-group`의 보안 리소스를 **생성/변경/삭제**하는 절차입니다.

대상 하위 유형:
- `application-security-group`
- `network-security-group`
- `network-security-rule`
- `security-policy`
- `subnet-network-security-group-association`

---

## 0) 사전 준비

```bash
az login
az account show -o table
terraform version
```

---

## 1) 생성(Create) 권장 순서

1. `application-security-group`
2. `network-security-group`
3. `network-security-rule`
4. `security-policy`
5. `subnet-network-security-group-association`

예시(리프 하나 적용):

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/01.network/security-group/network-security-group/hub-pep
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

---

## 2) 변경(Update)

예: 허용/차단 포트, 우선순위, source/destination, FQDN 규칙 변경

```bash
terraform fmt
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
terraform plan
```

변경 후 확인:

```bash
terraform state list
az network nsg list -g "<RG_NAME>" -o table
```

---

## 3) 삭제(Delete)

권장 역순:
1. association
2. rule
3. nsg/asg
4. policy

```bash
terraform plan -destroy
terraform destroy -auto-approve
terraform plan
```

---

## 4) 트러블슈팅

- `Priority conflict`:
  - NSG rule priority 중복 여부 확인 후 재적용
- `Referenced resource not found`:
  - ASG/NSG를 먼저 생성했는지 확인
- backend 오류:
  - Hub 구독 컨텍스트로 `az account set` 후 재시도
