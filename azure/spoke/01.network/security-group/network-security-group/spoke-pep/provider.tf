provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id            = var.spoke_subscription_id
  skip_provider_registration = true
}

provider "azapi" {
  subscription_id = var.spoke_subscription_id
}
