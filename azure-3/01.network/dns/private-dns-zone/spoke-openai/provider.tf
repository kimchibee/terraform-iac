provider "azurerm" {
  features {}
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}
