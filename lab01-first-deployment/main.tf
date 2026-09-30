# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

# TODO 1: Inspect this managed resource group.
# Explain how its name and location inputs control its creation and lifecycle.
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO 2: Complete this VNet. Reference the resource group's name and location,
# name it "vnet-tf-lab01-${var.unique_suffix}", and use 10.1.0.0/16.
resource "azurerm_virtual_network" "this" {
  name                = "TODO"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
}
