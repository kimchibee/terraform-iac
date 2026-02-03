# private-endpoint 모듈

**단일 책임**: 특정 Azure 리소스 1개에 대한 Private Endpoint 1개만 생성합니다.  
`private_dns_zone_ids`를 넘기면 Private DNS Zone 그룹도 함께 연결합니다.  
Storage(blob/file/queue), Key Vault(vault), OpenAI, APIM, ML 등 **스케일 아웃되는 PE 패턴**에 재사용합니다.

## 사용 예 (terraform-infra에서)

```hcl
# Storage Account Blob용 PE
module "pe_storage_blob" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/private-endpoint?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  name                 = "pe-${module.storage.name}-blob"
  location             = var.location
  resource_group_name  = module.hub_rg.name
  subnet_id            = module.hub_vnet.subnet_ids["pep-snet"]
  target_resource_id   = module.storage.id
  subresource_names    = ["blob"]
  private_dns_zone_ids = [var.private_dns_zone_ids["blob"]]
  tags                 = var.tags
}

# Key Vault용 PE
module "pe_key_vault" {
  source = "...//terraform_modules/private-endpoint?ref=v1.0.0"
  name   = "pe-${module.hub_key_vault.name}"
  # ...
  target_resource_id  = module.hub_key_vault.id
  subresource_names   = ["vault"]
  private_dns_zone_ids = [var.private_dns_zone_ids["vault"]]
}
```

## 입력/출력

- **variables.tf**: `name`, `location`, `resource_group_name`, `subnet_id`, `target_resource_id`, `subresource_names`, `private_connection_name`(선택), `private_dns_zone_ids`(선택), `tags`
- **outputs.tf**: `id`, `name`, `private_ip_address`

## subresource_names 참고

| 대상 리소스 | subresource_names 예시 |
|-------------|------------------------|
| Storage Account (Blob) | `["blob"]` |
| Storage Account (File) | `["file"]` |
| Key Vault | `["vault"]` |
| Azure OpenAI / Cognitive | `["account"]` 등 (서비스 문서 참고) |
| SQL Server | `["sqlServer"]` |
