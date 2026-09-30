# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}
resource "azurerm_virtual_network" "this" {
  name                = "vnet-tf-lab04-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
}

# TODO: Replace the repeated subnet shape from Lab 03 with one azurerm_subnet
# resource using for_each = var.subnets. Use each.key in the Azure name and
# each.value.address_prefix for its CIDR.
# Reference azurerm_resource_group.this.name and the VNet name.
