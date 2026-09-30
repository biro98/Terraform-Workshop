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
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = "snet-${replace(each.key, "_", "-")}"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.address_prefix]
}
