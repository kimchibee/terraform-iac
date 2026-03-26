# Private Endpoint + Private DNS Zone 연동 가이드 (복사/붙여넣기)

이 문서는 **처음 Terraform/Azure를 다루는 사람**도 따라할 수 있도록 작성된 실습형 가이드입니다.

목표:
- Private Endpoint(PE)를 만든다.
- PE가 가진 private IP/FQDN 정보를 기준으로 Private DNS A 레코드를 만든다.
- 이후 `terraform plan`에서 항상 `No changes`가 나오도록 드리프트를 없앤다.

---

## 0) 사전 준비

아래 명령을 그대로 실행해서 로그인/구독/버전을 확인합니다.

```bash
az login
az account show -o table
terraform version
```

권장:
- Terraform 1.6+ (현재 저장소 기준)
- Hub/Spoke 구독 모두 접근 가능한 계정

### 0.1 공통값 일관 주입 (권장)

루트에서 `scripts/deploy-stacks-sequential.sh`를 실행하면 아래 공통값을 자동 동기화합니다.

- `hub_subscription_id`, `spoke_subscription_id`
- `project_name`, `environment`, `location`
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name`

기준값 우선순위:
- 구독 ID: 환경변수(`HUB_SUBSCRIPTION_ID`, `SPOKE_SUBSCRIPTION_ID`) -> 프롬프트 입력
- `project_name`, `environment`, `location`: `azure/dev/01.network/resource-group/hub-rg/terraform.tfvars`
- backend 값: `bootstrap/backend/terraform.tfvars`

실행 예시:

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac
export HUB_SUBSCRIPTION_ID="<hub-subscription-id>"
export SPOKE_SUBSCRIPTION_ID="<spoke-subscription-id>"
bash ./scripts/deploy-stacks-sequential.sh
```

> DNS 리프만 단독으로 수동 실행할 때도, 위 기준값과 동일한 `terraform.tfvars`를 유지해야 드리프트를 줄일 수 있습니다.

---

## 1) 작업 디렉토리 이동

아래 예시는 AI 서비스 스택(`05.ai-services/workload`) 기준입니다.

```bash
cd /c/Users/nonoc/OneDrive/바탕\ 화면/challenge/terraform-iac/azure/dev/05.ai-services/workload
```

---

## 2) PE가 이미 있는지 확인 (없으면 먼저 생성)

아래는 현재 예시 리소스명입니다. 환경에 맞게 바꾸세요.

```bash
az account set --subscription "<SPOKE_SUBSCRIPTION_ID>"
az network private-endpoint show -g "<SPOKE_RG>" -n "<PE_NAME>" -o table
```

- 출력이 나오면 PE가 이미 존재합니다.
- 에러가 나면 PE 미생성 상태입니다. 이 경우 `terraform apply`로 PE를 먼저 만드세요.

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

주의:
- 이 저장소 구조에서는 backend가 Hub 쪽 Storage를 쓰므로, `init/plan/apply` 전에 Hub 구독 컨텍스트인지 확인하세요.

---

## 3) PE의 DNS 정보(customDnsConfigs) 확인

PE가 만들어지면 Azure가 `customDnsConfigs`에 FQDN + IP를 넣어줍니다.
이 값을 Terraform에서 읽어서 A 레코드를 동적으로 만들면 됩니다.

```bash
az account set --subscription "<SPOKE_SUBSCRIPTION_ID>"
az network private-endpoint show -g "<SPOKE_RG>" -n "<PE_NAME>" --query "customDnsConfigs" -o json
```

예상 결과(형식):
- `fqdn`: `xxxx.workspace.<region>.api.azureml.ms`
- `fqdn`: `xxxx.workspace.<region>.cert.api.azureml.ms`
- `fqdn`: `xxxx.<region>.notebooks.azure.net`
- `fqdn`: `*.xxxx.inference.<region>.api.azureml.ms`
- 각 항목에 `ipAddresses[0]`

---

## 4) Hub Private DNS Zone 존재 확인

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
az network private-dns zone list -g "<HUB_RG>" -o table
```

AI Foundry(AML Workspace) 기준 필요 zone:
- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`

없다면 먼저 생성하세요(별도 DNS 스택 또는 Azure Portal/CLI).

---

## 5) Terraform 코드 수정 (핵심)

아래 4개를 `main.tf`에 반영합니다.

1. Hub DNS zone 데이터 소스 추가
2. `azapi_resource`로 PE `customDnsConfigs` 읽기
3. FQDN suffix로 zone/record_name 매핑
4. `for_each`로 `azurerm_private_dns_a_record` 생성

아래는 바로 재사용 가능한 예시입니다.

```hcl
data "azurerm_private_dns_zone" "hub_azureml_api" {
  provider            = azurerm.hub
  name                = "privatelink.api.azureml.ms"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azurerm_private_dns_zone" "hub_notebooks" {
  provider            = azurerm.hub
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
}

data "azapi_resource" "ai_foundry_pe" {
  count = var.enable_private_endpoints && var.enable_ai_foundry_workspace ? 1 : 0

  type      = "Microsoft.Network/privateEndpoints@2024-07-01"
  parent_id = data.azurerm_resource_group.spoke.id
  name      = "${local.name_prefix}-aif-pe"

  response_export_values = ["properties.customDnsConfigs"]
}

locals {
  ai_foundry_pe_custom_dns = try(data.azapi_resource.ai_foundry_pe[0].output.properties.customDnsConfigs, [])

  ai_foundry_dns_records = [
    for cfg in local.ai_foundry_pe_custom_dns : {
      ip = try(cfg.ipAddresses[0], null)
      zone = endswith(lower(try(cfg.fqdn, "")), ".api.azureml.ms") ? data.azurerm_private_dns_zone.hub_azureml_api.name : (
        endswith(lower(try(cfg.fqdn, "")), ".notebooks.azure.net") ? data.azurerm_private_dns_zone.hub_notebooks.name : null
      )
      record_name = endswith(lower(try(cfg.fqdn, "")), ".api.azureml.ms") ? trimsuffix(lower(cfg.fqdn), ".api.azureml.ms") : (
        endswith(lower(try(cfg.fqdn, "")), ".notebooks.azure.net") ? trimsuffix(lower(cfg.fqdn), ".notebooks.azure.net") : null
      )
    } if try(cfg.fqdn, null) != null && try(cfg.ipAddresses[0], null) != null
  ]

  ai_foundry_dns_records_map = {
    for r in local.ai_foundry_dns_records : "${r.zone}::${r.record_name}" => r
    if r.zone != null && r.record_name != null
  }
}

resource "azurerm_private_dns_a_record" "ai_foundry_in_hub_zone" {
  for_each = local.ai_foundry_dns_records_map

  provider            = azurerm.hub
  name                = each.value.record_name
  zone_name           = each.value.zone
  resource_group_name = data.terraform_remote_state.network_hub.outputs.hub_resource_group_name
  ttl                 = 300
  records             = [each.value.ip]
}
```

---

## 6) 생성/변경 적용

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform fmt
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply -auto-approve tfplan
```

정상이라면:
- A 레코드가 신규 생성됨
- apply 결과에서 add 수가 표시됨

---

## 7) 결과 검증

1) Terraform 드리프트 확인

```bash
terraform plan
```

기대값:
- `No changes. Your infrastructure matches the configuration.`

2) 실제 DNS 레코드 확인

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
az network private-dns record-set a list -g "<HUB_RG>" -z "privatelink.api.azureml.ms" -o table
az network private-dns record-set a list -g "<HUB_RG>" -z "privatelink.notebooks.azure.net" -o table
```

---

## 8) 자주 발생하는 에러와 해결

### 에러 A: `already exists - to be managed via Terraform this resource needs to be imported`

원인:
- 같은 A 레코드를 수동으로 이미 만들었음

해결:
1. 에러 메시지의 Resource ID 확인
2. Terraform 주소로 import

```bash
terraform import 'azurerm_private_dns_a_record.ai_foundry_in_hub_zone["privatelink.api.azureml.ms::xxxx.workspace.koreacentral"]' \
"/subscriptions/<HUB_SUB_ID>/resourceGroups/<HUB_RG>/providers/Microsoft.Network/privateDnsZones/privatelink.api.azureml.ms/A/xxxx.workspace.koreacentral"
```

3. 다시 `terraform plan` 실행

---

### 에러 B: zone이 없어서 실패

원인:
- Hub에 `privatelink.api.azureml.ms` 또는 `privatelink.notebooks.azure.net` 미생성

해결:
- DNS zone 먼저 생성 후 다시 apply

---

### 에러 C: plan/apply 중 backend 스토리지 접근 실패

원인:
- Hub backend를 쓰는데 현재 CLI 구독이 Spoke로 되어 있음

해결:

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
```

후에 다시 `init/plan/apply`.

---

## 9) 핵심 개념 요약

- PE는 네트워크 인터페이스(사설 IP를 가진 엔드포인트)입니다.
- Private DNS Zone은 FQDN을 PE 사설 IP로 해석해 주는 DNS입니다.
- Terraform에서 둘 다 관리해야 드리프트 없이 재현 가능한 IaC가 됩니다.
- 가장 안정적인 패턴은:
  - PE 생성
  - PE의 `customDnsConfigs` 읽기
  - Zone/FQDN suffix 매핑
  - `for_each` A 레코드 생성

---

## 10) 삭제(runbook)

삭제는 반드시 **역순**으로 진행합니다.

1) 먼저 어떤 레코드/리소스가 삭제될지 확인

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform plan -destroy
```

2) 실제 삭제

```bash
az account set --subscription "<HUB_SUBSCRIPTION_ID>"
terraform destroy -auto-approve
```

3) 삭제 후 검증

```bash
terraform plan
az network private-dns record-set a list -g "<HUB_RG>" -z "privatelink.api.azureml.ms" -o table
az network private-dns record-set a list -g "<HUB_RG>" -z "privatelink.notebooks.azure.net" -o table
```

기대값:
- `terraform plan`에서 추가 변경 없음(`No changes`) 또는 삭제 완료 상태
- 해당 레코드가 DNS zone 목록에서 사라짐

