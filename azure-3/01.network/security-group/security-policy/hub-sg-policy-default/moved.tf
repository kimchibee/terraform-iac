# 직접 Registry AVM 참조 → 공동 모듈 래퍼(module.avm) 로 state 이전
# state 에 azurerm_firewall_policy.hub 만 있으면 수동: terraform state mv azurerm_firewall_policy.hub module.firewall_policy.module.avm.azurerm_firewall_policy.this
moved {
  from = module.firewall_policy.azurerm_firewall_policy.this
  to   = module.firewall_policy.module.avm.azurerm_firewall_policy.this
}
