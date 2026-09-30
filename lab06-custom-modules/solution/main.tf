# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}
module "network" {
  source = "./modules/network"

  name                = "vnet-tf-lab06-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.6.0.0/16"]
  subnets             = var.subnets
}
