# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  description = "Dedicated resource group owned by this root."
  value       = azurerm_resource_group.this.name
}

output "vnet_id" {
  value = module.virtual_network.resource_id
}
output "subnets" {
  value = module.virtual_network.subnets
}

output "application_nsg_id" {
  value = azurerm_network_security_group.application.id
}
