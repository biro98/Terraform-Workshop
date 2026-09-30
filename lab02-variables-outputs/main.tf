# SPDX-FileCopyrightText: 2026 biro98
# SPDX-License-Identifier: MIT

locals {
  # TODO: Build a prefix such as "tf-lab02-rv02" from unique_suffix.
  name_prefix = "TODO"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

# TODO: Create the virtual network using the variables and the managed
# group's azurerm_resource_group.this.name and .location attributes.

# TODO: Create the subnet and reference the VNet and managed resource group.
