moved {
  from = azurerm_route_table.spoke
  to   = module.route_table.module.avm.azurerm_route_table.this
}

moved {
  from = azurerm_route.spoke
  to   = module.route_table.module.avm.azurerm_route.this
}

moved {
  from = azurerm_subnet_route_table_association.spoke
  to   = module.route_table.module.avm.azurerm_subnet_route_table_association.this
}
