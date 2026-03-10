#!/usr/bin/env bash
#--------------------------------------------------------------
# Hub Key Vault "Key Vault Secrets User" 역할 할당이 이미 Azure에 있을 때
# (RoleAssignmentExists 409) Terraform state로 import
# 사용: compute 디렉터리에서 ../scripts/import-vm-key-vault-access.sh
#       또는 scripts/import-vm-key-vault-access.sh (compute가 현재 디렉터리)
#--------------------------------------------------------------
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPUTE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$COMPUTE_DIR"

echo "Getting VM identity principal_id and Key Vault scope from Terraform..."
PRINCIPAL_ID=$(terraform output -raw monitoring_vm_identity_principal_id 2>/dev/null || true)
if [ -z "$PRINCIPAL_ID" ]; then
  echo "Error: Could not get monitoring_vm_identity_principal_id. Run 'terraform apply' once or set it manually."
  exit 1
fi

KV_SCOPE=$(terraform console -var-file=terraform.tfvars -input=false <<< 'data.terraform_remote_state.storage.outputs.key_vault_id' 2>/dev/null | tr -d '"' | tr -d '\n' || true)
if [ -z "$KV_SCOPE" ] || [ "$KV_SCOPE" = "null" ]; then
  echo "Error: Could not get key_vault_id from storage remote state."
  exit 1
fi

echo "Looking up existing 'Key Vault Secrets User' role assignment..."
ASSIGNMENT_ID=$(az role assignment list --scope "$KV_SCOPE" --assignee "$PRINCIPAL_ID" --role "Key Vault Secrets User" --query "[0].id" -o tsv 2>/dev/null || true)
if [ -z "$ASSIGNMENT_ID" ]; then
  echo "Error: No existing role assignment found. Create it in Azure first or remove this script."
  exit 1
fi

echo "Importing azurerm_role_assignment.vm_key_vault_access[0]..."
terraform import 'azurerm_role_assignment.vm_key_vault_access[0]' "$ASSIGNMENT_ID"
echo "Done. Run: terraform apply -var-file=terraform.tfvars"
