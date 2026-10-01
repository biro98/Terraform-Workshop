# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01/providers/Microsoft.Network/networkSecurityGroups/mock"
    }
  }
  mock_resource "azurerm_route_table" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01/providers/Microsoft.Network/routeTables/spoke"
    }
  }
}

mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
      output = {}
    }
  }
}

mock_provider "modtm" {}
mock_provider "random" {}

override_resource {
  target = module.hub.azapi_resource.vnet
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01/providers/Microsoft.Network/virtualNetworks/hub"
  }
}

override_resource {
  target = module.spoke.azapi_resource.vnet
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-tf-lab09-solution-u01/providers/Microsoft.Network/virtualNetworks/spoke"
  }
}

run "example_contract" {
  command = apply

  assert {
    condition     = output.resource_group_name == var.resource_group_name && azurerm_resource_group.this.location == "swedencentral"
    error_message = "The solution must own the configured group in the example region."
  }

  assert {
    condition = (
      length(output.hub_subnet_ids) == 2 && length(output.spoke_subnet_ids) == 4 &&
      length(azurerm_network_security_group.spoke) == 4 &&
      toset(module.hub.address_spaces) == toset(var.hub_address_space) &&
      toset(module.spoke.address_spaces) == toset(var.spoke_address_space) &&
      alltrue([for key, subnet in module.hub.subnets :
        subnet.name == "snet-${replace(key, "_", "-")}" &&
        toset(subnet.resource.body.properties.addressPrefixes) == toset([var.hub_subnets[key].address_prefix]) &&
        subnet.resource.body.properties.networkSecurityGroup == null &&
        subnet.resource.body.properties.routeTable == null
      ])
    )
    error_message = "Hub/spoke inventory, CIDRs, and hub isolation from spoke policy must match the guide."
  }

  assert {
    condition = alltrue([for key, subnet in module.spoke.subnets :
      subnet.name == "snet-${replace(key, "_", "-")}" &&
      toset(subnet.resource.body.properties.addressPrefixes) == toset([var.spoke_subnets[key].address_prefix]) &&
      subnet.resource.body.properties.networkSecurityGroup.id == azurerm_network_security_group.spoke[key].id &&
      subnet.resource.body.properties.privateEndpointNetworkPolicies == (var.spoke_subnets[key].private_endpoint ? "Disabled" : "Enabled") &&
      (var.spoke_subnets[key].route_via_hub
        ? subnet.resource.body.properties.routeTable.id == output.spoke_route_table_id
      : subnet.resource.body.properties.routeTable == null)
    ])
    error_message = "Real AVM helpers must attach NSGs to all spoke subnets and route only flagged non-endpoint subnets."
  }

  assert {
    condition = (
      azurerm_network_security_rule.management_https.network_security_group_name == azurerm_network_security_group.spoke["application"].name &&
      azurerm_network_security_rule.management_https.source_address_prefix == var.management_cidr &&
      azurerm_network_security_rule.management_https.destination_port_range == "443" &&
      azurerm_network_security_rule.management_https.protocol == "Tcp" &&
      azurerm_network_security_rule.management_https.access == "Allow" &&
      azurerm_network_security_rule.management_https.direction == "Inbound" &&
      azurerm_network_security_rule.management_https.priority == 100 &&
      alltrue([for key, nsg in azurerm_network_security_group.spoke : nsg.name == "nsg-${replace(key, "_", "-")}-tf-lab09-${var.unique_suffix}"])
    )
    error_message = "Only application needs the scoped management HTTPS rule and lab-specific NSG names."
  }

  assert {
    condition = (
      azurerm_route.default_to_hub.address_prefix == "0.0.0.0/0" &&
      azurerm_route.default_to_hub.next_hop_type == "VirtualAppliance" &&
      azurerm_route.default_to_hub.next_hop_in_ip_address == var.hub_virtual_appliance_ip &&
      module.spoke.subnets.private_endpoints.resource.body.properties.routeTable == null
    )
    error_message = "The simulated default route must use the supplied hub IP and exclude private endpoints."
  }

  assert {
    condition = (
      length(output.peering_ids) == 2 &&
      azurerm_virtual_network_peering.hub_to_spoke.virtual_network_name == module.hub.name &&
      azurerm_virtual_network_peering.hub_to_spoke.remote_virtual_network_id == output.spoke_vnet_id &&
      azurerm_virtual_network_peering.spoke_to_hub.virtual_network_name == module.spoke.name &&
      azurerm_virtual_network_peering.spoke_to_hub.remote_virtual_network_id == output.hub_vnet_id &&
      azurerm_virtual_network_peering.hub_to_spoke.allow_virtual_network_access &&
      azurerm_virtual_network_peering.hub_to_spoke.allow_forwarded_traffic &&
      azurerm_virtual_network_peering.spoke_to_hub.allow_virtual_network_access &&
      azurerm_virtual_network_peering.spoke_to_hub.allow_forwarded_traffic
    )
    error_message = "Peering must be bidirectional, referencing actual VNet outputs with forwarding enabled."
  }

  assert {
    condition = (
      azurerm_private_dns_zone.this.name == "privatelink.blob.core.windows.net" &&
      length(azurerm_private_dns_zone_virtual_network_link.this) == 2 &&
      azurerm_private_dns_zone_virtual_network_link.this["hub"].virtual_network_id == output.hub_vnet_id &&
      azurerm_private_dns_zone_virtual_network_link.this["spoke"].virtual_network_id == output.spoke_vnet_id &&
      alltrue([for link in azurerm_private_dns_zone_virtual_network_link.this : !link.registration_enabled])
    )
    error_message = "The canonical zone must link to both VNets without registration."
  }
}
