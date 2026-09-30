# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO 1: Create vnet-tf-lab03-<suffix> with address space 10.10.0.0/16.
# Use azurerm_resource_group.this.name and .location.

# TODO 2: Create three separate azurerm_subnet resources:
# application 10.10.1.0/24, data 10.10.2.0/24, and
# private-endpoint 10.10.3.0/24. Disable private endpoint network policies on
# the private-endpoint subnet.

# TODO 3: Create nsg-tf-lab03-application-<suffix> in the managed group's name
# and location, with one inbound rule allowing HTTPS from
# VirtualNetwork, then associate it only with the application subnet.
