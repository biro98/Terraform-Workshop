# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO: Create an application NSG and an inbound TCP 443 rule restricted to
# var.management_cidr. Use a lab08-specific NSG name and the resource group's
# managed resource for its name and location. The NSG remains owned by this root.

# TODO: Add module "virtual_network" using source
# "Azure/avm-res-network-virtualnetwork/azurerm" and version "0.22.2".
# Configure name, location, parent_id, address_space, and a transformed subnets
# map using azurerm_resource_group.this.location and .id for the region
# and parent. Use a lab08-specific VNet name. Transform the supplied subnet
# map. Each AVM subnet needs name and address_prefixes. Disable private endpoint
# network policies only for the private_endpoints key. Pass the application NSG
# ID through that subnet's network_security_group object.
