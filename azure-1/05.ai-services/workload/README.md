# AI Services Workload (05)

`05.ai-services/workload`는 Spoke 구독 기준으로 아래 리소스를 생성합니다.

- Azure OpenAI 계정
- AI Foundry용 Azure ML Workspace
- AI Foundry 의존 리소스(Log Analytics, Application Insights, Storage Account, Key Vault)
- Spoke Private Endpoint 2종(OpenAI, AI Foundry Workspace)

State 키: `azure/dev/05.ai-services/workload/terraform.tfstate`

## 선행 스택

1. `01.network` (특히 `vnet/spoke-vnet`, `subnet/spoke-pep-subnet`)
2. `02.storage`
3. `03.shared-services`
4. `04.apim`

## 주요 변수

- `project_name`, `environment`, `location`, `tags`
- `spoke_subscription_id`
- `backend_resource_group_name`, `backend_storage_account_name`, `backend_container_name`
- `openai_sku`, `openai_deployments`
- `enable_ai_foundry_workspace` (default: `true`)
- `enable_private_endpoints` (default: `true`)

## 배포 명령

```bash
cd azure/dev/05.ai-services/workload
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 값 수정
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## 출력값

- `openai_id`, `openai_endpoint`
- `ai_foundry_id`, `ai_foundry_discovery_url`
- `openai_private_endpoint_id`, `ai_foundry_private_endpoint_id`
- `storage_account_id`, `key_vault_id`

## 참고

- AI Foundry Workspace 이름 충돌(soft-delete) 방지를 위해 suffix 기반 네이밍을 사용합니다.
- Azure Provider namespace 미등록 시 `MissingSubscriptionRegistration` 오류가 발생할 수 있으므로, 사전에 `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.Insights` 등록을 권장합니다.
