# vnet 모듈

**단일 책임**: Virtual Network 1개와 서브넷만 생성합니다.  
Resource Group은 호출 측(terraform-infra)에서 생성·관리하고, `resource_group_name`으로 전달합니다.  
VPN Gateway, DNS Private Resolver, NSG 등은 별도 모듈로 분리하는 것을 권장합니다.

## 사용 예 (terraform-infra에서)

```hcl
module "vnet" {
  source = "git::https://github.com/your-org/terraform-infra.git//terraform_modules/vnet?ref=v1.0.0"

  project_name         = var.project_name
  environment          = var.environment
  location             = var.location
  resource_group_name  = azurerm_resource_group.hub.name
  vnet_name            = local.vnet_name
  vnet_address_space   = ["10.0.0.0/16"]
  subnets              = var.subnets
  tags                 = var.tags
}
```

## 입력/출력

- **variables.tf**: `project_name`, `environment`, `location`, `resource_group_name`, `vnet_name`, `vnet_address_space`, `subnets`, `tags`
- **outputs.tf**: `vnet_id`, `vnet_name`, `vnet_address_space`, `subnet_ids` (이름 → ID 맵)

환경(dev/stage/prod) 값은 호출 측에서 변수로 전달합니다.
