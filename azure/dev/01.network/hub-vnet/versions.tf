terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.75.0" }
    azapi   = { source = "azure/azapi", version = "~> 1.9.0" }
    random  = { source = "hashicorp/random", version = "~> 3.5.0" }
  }
}
