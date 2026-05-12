# Hub 구독 리소스에 대한 진단 설정
provider "azurerm" {
  features {}
  subscription_id            = var.hub_subscription_id
  skip_provider_registration = true
}
