# 네이티브 UDR → 공동 모듈(AVM). association 이 없으면 세 번째 moved 는 제거하세요.
moved {
  from = azurerm_route_table.hub
  to   = module.route_table.module.avm.azurerm_route_table.this
}

moved {
  from = azurerm_route.hub
  to   = module.route_table.module.avm.azurerm_route.this
}

moved {
  from = azurerm_subnet_route_table_association.monitoring_vm[0]
  to   = module.route_table.module.avm.azurerm_subnet_route_table_association.this["monitoring_vm"]
}
