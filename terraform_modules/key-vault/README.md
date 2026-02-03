# key-vault 모듈

**단일 책임**: Key Vault 1개와 sku/soft_delete/network_acls 등 기본 설정만 담당합니다.  
Private Endpoint는 **private-endpoint** 모듈로 별도 생성하고, 시크릿/키/정책은 terraform_iac 또는 별도 리소스에서 관리합니다.

## 사용 예 (terraform-infra에서)

```hcl
module "hub_key_vault" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/key-vault?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  name                 = local.key_vault_name
  location             = var.location
  resource_group_name  = module.hub_rg.name
  purge_protection_enabled = var.environment == "prod"
  public_network_access_enabled = false
  network_acls = {
    default_action            = "Deny"
    virtual_network_subnet_ids = [var.pep_subnet_id, var.monitoring_vm_subnet_id]
  }
  tags = var.tags
}

# PE는 별도 모듈
module "kv_private_endpoint" {
  source = "...//terraform_modules/private-endpoint?ref=v1.0.0"
  # ...
  target_resource_id = module.hub_key_vault.id
  subresource_names  = ["vault"]
  private_dns_zone_ids = [var.private_dns_zone_ids["vault"]]
}
```

## 입력/출력

- **variables.tf**: `name`, `location`, `resource_group_name`, `sku_name`, `soft_delete_retention_days`, `purge_protection_enabled`, `public_network_access_enabled`, `network_acls`, `tags`
- **outputs.tf**: `id`, `name`, `vault_uri`
