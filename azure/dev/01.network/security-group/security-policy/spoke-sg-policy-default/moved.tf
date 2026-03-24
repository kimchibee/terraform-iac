# 직접 Registry AVM → 공동 모듈 래퍼(module.avm)
# state 에 azurerm_firewall_policy.spoke 만 있으면 수동: terraform state mv azurerm_firewall_policy.spoke module.firewall_policy.module.avm.azurerm_firewall_policy.this
moved {
  from = module.firewall_policy.azurerm_firewall_policy.this
  to   = module.firewall_policy.module.avm.azurerm_firewall_policy.this
}
