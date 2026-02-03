#--------------------------------------------------------------
# AI Foundry Module Variables
# 이 디렉터리(모듈)가 외부에서 입력받는 변수 정의 파일
#--------------------------------------------------------------

#--------------------------------------------------------------
# General Variables
#--------------------------------------------------------------
variable "project_name" {
  description = "Project name prefix"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default     = {}
}

#--------------------------------------------------------------
# Resource Group
#--------------------------------------------------------------
variable "resource_group_name" {
  description = "Resource Group name"
  type        = string
}

#--------------------------------------------------------------
# Virtual Network
#--------------------------------------------------------------
variable "vnet_name" {
  description = "Virtual Network name"
  type        = string
}

variable "vnet_resource_group_name" {
  description = "Virtual Network resource group name"
  type        = string
}

variable "pep_subnet_name" {
  description = "Private Endpoint Subnet name"
  type        = string
  default     = "pep-snet"
}

#--------------------------------------------------------------
# AI Foundry Configuration
#--------------------------------------------------------------
variable "ai_foundry_name" {
  description = "AI Foundry (ML Workspace) name"
  type        = string
}

#--------------------------------------------------------------
# Compute Clusters (for frequent changes)
#--------------------------------------------------------------
variable "compute_clusters" {
  description = "Map of compute clusters to create"
  type = map(object({
    vm_size     = string
    min_nodes   = number
    max_nodes   = number
    vm_priority = optional(string, "Dedicated") # Dedicated or LowPriority
  }))
  default = {}
}

#--------------------------------------------------------------
# Model Deployments (for frequent changes)
#--------------------------------------------------------------
variable "model_deployments" {
  description = "Map of model deployments"
  type = map(object({
    model_name   = string
    version      = string
    compute_type = optional(string, "Managed") # Managed or Kubernetes
    environment  = optional(string, "")
  }))
  default = {}
}

#--------------------------------------------------------------
# Datasets (for frequent changes)
#--------------------------------------------------------------
variable "datasets" {
  description = "Map of datasets to register"
  type = map(object({
    source_type = string  # File, Tabular, etc.
    path        = string
    description = optional(string, "")
  }))
  default = {}
}

#--------------------------------------------------------------
# Environment Configuration
#--------------------------------------------------------------
variable "environments" {
  description = "Map of ML environments (Python/Conda)"
  type = map(object({
    conda_file     = optional(string, "")
    docker_image   = optional(string, "")
    python_version = optional(string, "3.8")
  }))
  default = {}
}

#--------------------------------------------------------------
# Key Vault
#--------------------------------------------------------------
variable "hub_key_vault_id" {
  description = "Hub Key Vault ID to use for AI Foundry"
  type        = string
}

#--------------------------------------------------------------
# Log Analytics
#--------------------------------------------------------------
variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  type        = string
  default     = ""
}

#--------------------------------------------------------------
# Private DNS Zones
#--------------------------------------------------------------
variable "private_dns_zone_ids" {
  description = "Map of Private DNS Zone IDs"
  type = map(string)
  default = {}
}

#--------------------------------------------------------------
# Existing Resources (for reuse)
#--------------------------------------------------------------
variable "existing_storage_account_name" {
  description = "Existing Storage Account name to reuse (optional)"
  type        = string
  default     = null
}

variable "existing_acr_name" {
  description = "Existing Container Registry name to reuse (optional)"
  type        = string
  default     = null
}
