# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

output "resource_group_name" {
  description = "Dedicated resource group owned by this lab."
  value       = azurerm_resource_group.this.name
}

output "virtual_networks" {
  description = "Hub and spoke names and resource IDs."
  value = {
    hub   = { name = module.connectivity.name["hub"], id = module.connectivity.resource_id["hub"] }
    spoke = { name = module.spoke.name, id = module.spoke.resource_id }
  }
}

output "peering_ids" {
  description = "Both directions of direct VNet peering."
  value = {
    hub_to_spoke = azurerm_virtual_network_peering.hub_to_spoke.id
    spoke_to_hub = azurerm_virtual_network_peering.spoke_to_hub.id
  }
}

output "platform_services" {
  description = "Pattern-owned Bastion, hub-only NAT Gateway and DNS Resolver."
  value = {
    bastion_id     = module.connectivity.bastion_host_resource_ids["hub"]
    nat_gateway_id = module.connectivity.nat_gateway_resource_ids["hub"]
    resolver_id    = module.connectivity.dns_resolver_resource_ids["hub"]
  }
}

output "resolver_inbound_ip_addresses" {
  description = "Private resolver endpoint IPs; no private path is configured from the management client."
  value       = module.connectivity.dns_resolver_inbound_endpoint_ip_addresses["hub"]
}

output "private_dns_zone_ids" {
  description = "Only the selected zones, created by the nested DNS pattern."
  value       = module.connectivity.private_dns_zone_resource_ids["hub"]
}
