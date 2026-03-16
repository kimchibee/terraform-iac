#--------------------------------------------------------------
# Spoke VNet 모듈 (network 루트에서 호출)
#
# [신규 Spoke 추가 시 이 폴더를 통째로 복사한 뒤]
# 1. 폴더명 변경: 예) spoke-vnet → spoke-vnet-02
# 2. 이 파일(main.tf)은 수정 불필요. (source는 루트에서 "./spoke-vnet-02"로 지정)
# 3. network 루트에서 수정할 것:
#    - main.tf: locals에 spoke_02용 resource_group_name, vnet_name, subnets 추가
#              + module "spoke_vnet_02" { source = "./spoke-vnet-02"; project_name = ...; resource_group_name = local.spoke_02_rg_name; vnet_name = local.spoke_02_vnet_name; vnet_address_space = var.spoke_02_vnet_address_space; subnets = local.spoke_02_subnets; hub_vnet_id = module.hub_vnet.vnet_id; hub_resource_group_name = module.hub_vnet.resource_group_name; private_dns_zone_ids = local.hub_zone_ids_for_spoke_link; spoke_private_dns_zones = local.spoke_private_dns_zones; ... } 추가
#    - variables.tf: spoke_02_vnet_address_space, spoke_02_subnets 등 변수 추가
#    - terraform.tfvars: 위 변수 값 설정
#--------------------------------------------------------------
module "spoke_vnet" {
  source = "./terraform_modules/spoke-vnet"

  providers = {
    azurerm     = azurerm
    azurerm.hub = azurerm.hub
  }

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags

  resource_group_name = var.resource_group_name
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space
  subnets             = var.subnets

  enable_hub_peering     = false
  hub_vnet_id            = var.hub_vnet_id
  hub_resource_group_name = var.hub_resource_group_name
  enable_private_dns_links = true
  private_dns_zone_ids      = var.private_dns_zone_ids
  spoke_private_dns_zones  = var.spoke_private_dns_zones
  enable_pep_nsg           = true
  pep_subnet_name          = "pep-snet"
}
