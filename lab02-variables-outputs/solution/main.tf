# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

locals {
  name_prefix = "tf-lab02-${var.unique_suffix}"
  common_tags = { environment = "training", workload = local.name_prefix }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "this" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.subnet_prefix]
}

moved {
  from = azurerm_subnet.application
  to   = azurerm_subnet.this
}
