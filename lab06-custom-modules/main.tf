# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO: Call ./modules/network. Pass the managed resource group's name and location,
# the lab-specific VNet name vnet-tf-lab06-${var.unique_suffix},
# address space, and subnets. Do not create network resources in this root.
