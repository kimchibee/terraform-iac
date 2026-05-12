# Spoke 구독에서 Spoke→Hub 피어링만 생성
provider "azurerm" {
  features {}
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
  alias                      = "spoke"
}
