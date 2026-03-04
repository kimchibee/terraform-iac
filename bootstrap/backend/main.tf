#--------------------------------------------------------------
# Bootstrap: Backend Storage Account and Container
# Terraform State를 저장할 Backend 리소스를 생성
# 이 스택은 최초 1회만 실행 (Backend가 이미 있으면 생략)
#--------------------------------------------------------------

terraform {
  required_version = "~> 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  skip_provider_registration = true
}

#--------------------------------------------------------------
# Resource Group for Backend
#--------------------------------------------------------------
resource "azurerm_resource_group" "backend" {
  name     = var.resource_group_name
  location = var.location

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Storage Account for Terraform State
#--------------------------------------------------------------
resource "azurerm_storage_account" "tf_state" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.backend.name
  location                 = azurerm_resource_group.backend.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  # Security (Backend는 init/plan/apply 시 접근 필요; Private Endpoint 배포 후 false 전환 가능)
  public_network_access_enabled = true
  allow_nested_items_to_be_public = false

  # Enable versioning
  blob_properties {
    versioning_enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

#--------------------------------------------------------------
# Storage Container for Terraform State
#--------------------------------------------------------------
resource "azurerm_storage_container" "tfstate" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.tf_state.name
  container_access_type = "private"
}

#--------------------------------------------------------------
# Private Endpoint for Storage Account (subnet_id 있을 때만 생성)
#--------------------------------------------------------------
resource "azurerm_private_endpoint" "storage" {
  count               = length(trimspace(var.subnet_id)) > 0 ? 1 : 0
  name                = "pe-${var.storage_account_name}"
  location            = azurerm_resource_group.backend.location
  resource_group_name = azurerm_resource_group.backend.name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "psc-${var.storage_account_name}"
    private_connection_resource_id = azurerm_storage_account.tf_state.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  tags = var.tags
}
