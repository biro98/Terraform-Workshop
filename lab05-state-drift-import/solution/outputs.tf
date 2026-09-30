# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}
output "virtual_network_id" {
  value = azurerm_virtual_network.this.id
}

output "current_subscription_id" {
  description = "Subscription selected by the active AzureRM provider session."
  value       = data.azurerm_client_config.current.subscription_id
}
