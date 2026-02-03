# storage-account 모듈

**단일 책임**: Storage Account 1개와 계정 티어·복제·TLS·네트워크 규칙 등 기본 설정만 담당합니다.  
Private Endpoint, Blob/Queue 컨테이너 등은 별도 모듈 또는 terraform-infra에서 구성하는 것을 권장합니다.

## 사용 예 (terraform-infra에서)

```hcl
module "logs_storage" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/storage-account?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = azurerm_resource_group.hub.name
  name_prefix          = "logs"
  account_replication_type = "LRS"
  public_network_access_enabled = false
  network_rules = {
    default_action            = "Deny"
    virtual_network_subnet_ids = [var.pep_subnet_id]
  }
  tags = var.tags
}
```

## 입력/출력

- **variables.tf**: `project_name`, `environment`, `location`, `resource_group_name`, `storage_account_name`(선택), `name_prefix`, `account_tier`, `account_replication_type`, `min_tls_version`, `public_network_access_enabled`, `network_rules`, `tags`
- **outputs.tf**: `storage_account_id`, `storage_account_name`, `primary_blob_endpoint`, `primary_access_key`(sensitive)

환경별 값(예: `public_network_access_enabled`는 prod에서 false)은 terraform-infra에서 변수로 제어합니다.
