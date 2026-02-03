# resource-group 모듈

**단일 책임**: Resource Group 1개만 생성합니다.  
다른 모듈(vnet, storage-account, key-vault 등)은 `resource_group_name`을 받으므로, RG를 먼저 이 모듈로 만든 뒤 이름을 전달하면 됩니다.

## 사용 예 (terraform-infra에서)

```hcl
module "hub_rg" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/resource-group?ref=v1.0.0"

  name     = local.hub_resource_group_name
  location = var.location
  tags     = var.tags
}

module "vnet" {
  source = "..."

  resource_group_name = module.hub_rg.name
  # ...
}
```

## 입력/출력

- **variables.tf**: `name`, `location`, `tags`
- **outputs.tf**: `id`, `name`, `location`
