# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# Build the complete hub-and-spoke design from the requirements in README.md.
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO: Use the managed resource group's name, location, and ID for all
# root resources and AVM parent IDs; use lab09-specific VNet, NSG, and route
# table names. This root owns its own group, independent from every other lab.
# TODO: Create one NSG per spoke subnet with for_each and permit management
# HTTPS only on the application NSG.
# TODO: Create a spoke route table and a default route to the configurable
# central appliance IP. The appliance itself is intentionally not deployed.
# TODO: Consume the pinned AVM VNet module twice: once for the hub and once for
# the spoke. Associate NSGs and the route table through spoke subnet inputs.
# TODO: Create bidirectional hub/spoke peerings with forwarded traffic enabled.
# TODO: Create the private DNS zone and link it to both VNets.
