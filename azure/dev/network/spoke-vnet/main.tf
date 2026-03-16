#--------------------------------------------------------------
# Spoke VNet 모듈 (network 루트에서 호출)
# 리소스 정보(VNet 주소 공간, 서브넷, 이름 접미사)는 이 폴더 variables.tf 기본값에서 관리.
# 루트는 name_prefix, hub_vnet_id, hub_resource_group_name, private_dns_zone_ids 등 컨텍스트만 전달.
#
# [신규 Spoke 추가 시]
# 1. 이 폴더를 통째로 복사 후 폴더명 변경 (예: spoke-vnet-02)
# 2. 복사한 폴더의 variables.tf에서 rg_suffix, vnet_suffix, vnet_address_space, subnets만 수정
# 3. 루트 main.tf에 module "spoke_vnet_02" { source = "./spoke-vnet-02"; name_prefix = local.name_prefix; hub_vnet_id = ...; ... } 추가
#    (루트 variables.tf / tfvars에 Spoke별 변수 추가 불필요)
#--------------------------------------------------------------
locals {
  resource_group_name = "${var.name_prefix}-${var.rg_suffix}"
  vnet_name           = "${var.name_prefix}-${var.vnet_suffix}"
}

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

  resource_group_name = local.resource_group_name
  vnet_name           = local.vnet_name
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
