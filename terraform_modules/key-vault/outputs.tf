#-------------------------------------------------------------------------------
# Key Vault 모듈 - 출력
#-------------------------------------------------------------------------------

output "id" {
  description = "Key Vault 리소스 ID"
  value       = azurerm_key_vault.main.id
}

output "name" {
  description = "Key Vault 이름"
  value       = azurerm_key_vault.main.name
}

output "vault_uri" {
  description = "Key Vault URI (시크릿/키 API용)"
  value       = azurerm_key_vault.main.vault_uri
}
