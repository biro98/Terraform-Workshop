# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

locals {
  tags = {
    environment = "training"
    owner       = "network-team"
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# Bootstrap only the RG first (see README), create this VNet with Azure CLI,
# then import it before a full apply.
resource "azurerm_virtual_network" "this" {
  name                = "vnet-tf-lab05-${var.unique_suffix}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.5.0.0/16"]
  tags                = local.tags
}
