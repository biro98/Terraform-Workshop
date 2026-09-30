# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "application_subnet_id" {
  value = azurerm_subnet.application.id
}
output "data_subnet_id" {
  value = azurerm_subnet.data.id
}
output "private_endpoints_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}
