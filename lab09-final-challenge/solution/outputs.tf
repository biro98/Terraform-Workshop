# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  description = "Dedicated resource group owned by this root."
  value       = azurerm_resource_group.this.name
}

output "hub_vnet_id" {
  value = module.hub.resource_id
}

output "spoke_vnet_id" {
  value = module.spoke.resource_id
}

output "hub_subnet_ids" {
  value = { for name, subnet in module.hub.subnets : name => subnet.resource_id }
}

output "spoke_subnet_ids" {
  value = { for name, subnet in module.spoke.subnets : name => subnet.resource_id }
}

output "peering_ids" {
  value = {
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke.id
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub.id
  }
}

output "spoke_route_table_id" {
  value = azurerm_route_table.spoke.id
}

output "private_dns_zone_id" {
  value = azurerm_private_dns_zone.this.id
}
